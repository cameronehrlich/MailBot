# MailBotExtension

MailBotExtension is a macOS Mail.app extension that leverages AI (using GPT-4) to automatically analyze incoming emails and determine the appropriate actions to perform. It integrates with the MailKit framework to process email messages and execute actions such as moving emails, marking them as read/unread, flagging, or setting background colors—either based on custom user rules or AI-driven decisions.

## Features

- **Automated Email Filtering:**  
  Uses an AI language model (GPT-4) to analyze incoming emails and decide on an appropriate action based on the email's content and metadata.

- **Custom User Rules:**  
  Supports custom rules (e.g., automatically flag emails from certain senders or archive specific messages) that override the AI decision when applicable.

- **MailKit Integration:**  
  Implements the `MEMessageActionHandler` protocol to seamlessly integrate with Mail.app's message processing pipeline.

- **Secure API Configuration:**  
  Load your OpenAI API key via environment variables to ensure sensitive data isn’t hardcoded in the repository.

## Requirements

- **macOS:** 12.0 or later  
- **Xcode:** 13 or later  
- **MailKit Framework:** (Included via Xcode project configuration)  
- **OpenAI API Key:** (Set via an environment variable, e.g., `OPENAI_API_KEY`)

## Installation

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/cameronehrlich/MailBot.git
   cd MailBot
   ```

2. Open the Project in Xcode:

    ```bash
    open MailBot.xcodeproj
    ```

3.	Configure the API Key:

	•	Update your scheme or add a configuration file to load the OPENAI_API_KEY environment variable.

	•	Make sure your working copy does not contain any hardcoded API keys.

4.	Build and Run:

    • Build the project in Xcode and install the extension. MailBotExtension will automatically integrate with Mail.app to process incoming emails.

## Usage

Once installed, MailBotExtension will process all incoming emails.


## Contributing

Contributions are welcome! To contribute:
	1.	Fork the repository.
	2.	Create a new branch for your changes.
	3.	Make your improvements or bug fixes.
	4.	Submit a pull request with a clear description of your changes.

Please ensure your changes do not expose any sensitive information (such as API keys).