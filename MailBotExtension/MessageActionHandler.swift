//
//  MessageActionHandler.swift
//  MailBotExtension
//
//  Created by Cameron Ehrlich on 1/3/25.
//

import MailKit

/// TODOs:
/// - Add support for user to provide custom instructions to the prompt
/// - Add pre-defined behavior (label this, arvhive that, etc.) to the prompt.
/// - Companion Mac app for viewing rules and actions taken throughout the day
/// - Break into testable pieces.

class MessageActionHandler: NSObject, MEMessageActionHandler {
    static let shared = MessageActionHandler()

    func decideAction(for message: MEMessage, completionHandler: @escaping (MEMessageActionDecision?) -> Void) {
        guard message.rawData != nil else {
            return completionHandler(.invokeAgainWithBody)
        }

        // TODO: Maybe custom decisions need more than just the sender's email address...
        if let customDecision = decisionFromCustomRules(for: message.fromAddress) {
            return completionHandler(customDecision)
        }

        Task {
            do {
                let lmResponse = try await processEmailWithLM(message: message)
                if let decision = mapLMResponseToActionDecision(lmResponse) {
                    completionHandler(decision)
                } else {
                    completionHandler(nil)
                }
            } catch {
                print("LM processing error: \(error)")
                completionHandler(nil)
            }
        }
    }
}

func mapLMResponseToActionDecision(_ lmResponse: LMDecisionResponse) -> MEMessageActionDecision? {
    var actions: [MEMessageAction] = []
    for choice in lmResponse.actions {
        guard let action = choice.parameters?["action"] else {
            print("LM response missing action parameter")
            return nil
        }
        switch action {
        case "moveToTrash":
            actions.append(.moveToTrash)
        case "moveToArchive":
            actions.append(.moveToArchive)
        case "moveToJunk":
            actions.append(.moveToJunk)
        case "markAsRead":
            actions.append(.markAsRead)
        case "markAsUnread":
            actions.append(.markAsUnread)
        case "flag":
            guard let color = choice.parameters?["color"] else {
                print("LM response missing color parameter for flag action")
                return nil
            }
            switch color {
            case "red":
                actions.append(.flag(.red))
            case "orange":
                actions.append(.flag(.orange))
            case "yellow":
                actions.append(.flag(.yellow))
            case "green":
                actions.append(.flag(.green))
            case "blue":
                actions.append(.flag(.blue))
            case "purple":
                actions.append(.flag(.purple))
            case "gray":
                actions.append(.flag(.gray))
            case "defaultColor":
                actions.append(.flag(.defaultColor))
            default:
                print("Invalid color parameter in LM response for flag action")
                return nil
            }
        case "setBackgroundColor":
            guard let color = choice.parameters?["color"] else {
                print("LM response missing color parameter for setBackgroundColor action")
                return nil
            }
            switch color {
            case "none":
                actions.append(.setBackgroundColor(.none))
            case "green":
                actions.append(.setBackgroundColor(.green))
            case "yellow":
                actions.append(.setBackgroundColor(.yellow))
            case "orange":
                actions.append(.setBackgroundColor(.orange))
            case "red":
                actions.append(.setBackgroundColor(.red))
            case "purple":
                actions.append(.setBackgroundColor(.purple))
            case "blue":
                actions.append(.setBackgroundColor(.blue))
            case "gray":
                actions.append(.setBackgroundColor(.gray))
            default:
                print("Invalid color parameter in LM response for setBackgroundColor action")

            }
        default:
            print("Invalid action in LM response")
            return nil
        }
    }
    return MEMessageActionDecision.actions(actions)
}

// MARK: - LM API Response Model

/// The model for the LM's JSON response.
struct LMDecisionResponse: Decodable {
    struct LMAction: Decodable {
        let action: String
        let parameters: [String: String]?
    }
    let actions: [LMAction]
}

// MARK: - LM Integration

/// Sends the email content (and any custom instructions) to the LM API and returns the parsed LMActionResponse.
@available(macOS 12.0, *)
func processEmailWithLM(message: MEMessage) async throws -> LMDecisionResponse {

    let state: String = {
        switch message.state {
        case .received:
            return "received"
        case .draft:
            return "draft"
        case .sending:
            return "sending"
        @unknown default:
            return "unknown"
        }
    }()
    let encryptionState: String = {
        switch message.encryptionState {
        case .encrypted:
            return "encrypted"
        case .notEncrypted:
            return "notEncrypted"
        case .unknown:
            fallthrough
        @unknown default:
            return "unknown"
        }
    }()
    let subject = message.subject
    let fromAddress = message.fromAddress.rawString
    let toAddresses = message.toAddresses.map { $0.rawString }
    let ccAddresses = message.ccAddresses.map { $0.rawString }
    let bccAddresses = message.bccAddresses.map { $0.rawString }
    let replyToAddresses = message.replyToAddresses.map { $0.rawString }
    let allRecipientAddresses = message.allRecipientAddresses.map { $0.rawString }
    let headers = message.headers?.map { (key, values) in "\(key): \(values.joined(separator: ", "))"}.joined(separator: "\n") ?? ""

    // TODO: Maybe use Mime parsing package to parse: https://github.com/miximka/MimeParser
    let rawData: String = {
        guard let data = message.rawData else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }()

    let allowedActionsDescription = """
    The permitted actions are:
    - moveToTrash
    - moveToArchive
    - moveToJunk
    - markAsRead
    - markAsUnread
    - flag: requires a parameter "color" which can be one of [red, orange, yellow, green, blue, purple, gray, defaultColor]
    - setBackgroundColor: requires a parameter "color" which can be one of [none, green, yellow, orange, red, purple, blue, gray]
    """

    var prompt = """
    \(allowedActionsDescription)
    
    Analyze the following email and decide which one of the above actions to perform. Respond ONLY in JSON format as follows:
    
    [{
      "action": "<action>",
      "parameters": { "key": "value", ... }
    }, ...]
    
    Make sure you match the casing and spelling of the actions and parameters exactly as shown above.
    
    Email State: \(state)
    Encryption State: \(encryptionState)
    Subject: \(subject)
    From: \(fromAddress)
    To: \(toAddresses)
    CC: \(ccAddresses)
    BCC: \(bccAddresses)
    Reply-To: \(replyToAddresses)
    All Recipients: \(allRecipientAddresses)
    Headers: \(headers)
    
    Email Content:
    \(rawData)
    """

// TODO: Add support for user to provide custom instructions to the prompt?
//    if let instructions = customInstructions {
//        prompt = "User Custom Instructions: \(instructions)\n" + prompt
//    }

    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        throw NSError(domain: "Invalid URL", code: -1)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    request.addValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")

    let requestBody: [String: Any] = [
        "model": "gpt-4o",
        "messages": [
            [
                "role": "system",
                "content": "You are an email automation assistant. Follow the user’s custom instructions and only select from the allowed actions provided."
            ],
            [
                "role": "user",
                "content": prompt
            ]
        ],
        "temperature": 0.0  // Deterministic output is preferred.
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)
    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        throw NSError(domain: "OpenAI API error", code: httpResponse.statusCode, userInfo: nil)
    }

    guard
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let choices = jsonResponse["choices"] as? [[String: Any]],
        let firstChoice = choices.first,
        let message = firstChoice["message"] as? [String: Any],
        let content = message["content"] as? String,
        let actionData = content.data(using: .utf8)
    else {
        throw NSError(domain: "ParsingError", code: -1, userInfo: nil)
    }
    let lmResponse = try JSONDecoder().decode(LMDecisionResponse.self, from: actionData)
    return lmResponse
}

// MARK: - Custom Rules
struct CustomRule {
    let senderContains: String
    let actionDecision: MEMessageActionDecision
}

// Example custom rule: if the sender contains "restaurant.com", mark as red and archive.
let userCustomRules: [CustomRule] = [
    CustomRule(
        senderContains: "restaurant.com",
        actionDecision: .actions([
            MEMessageAction.flag(.red),
            MEMessageAction.moveToArchive
        ])
    )
]

/// Checks if a sender string matches any custom rules.
@available(macOS 12.0, *)
func decisionFromCustomRules(for sender: MEEmailAddress) -> MEMessageActionDecision? {
    for rule in userCustomRules {
        if let addressString = sender.addressString?.lowercased(),
            addressString.contains(rule.senderContains.lowercased()) {
            return rule.actionDecision
        }
    }
    return nil
}
