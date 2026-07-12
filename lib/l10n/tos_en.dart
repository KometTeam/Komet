const String kTermsOfServiceEn = r'''
Terms of use for the unofficial MAX client named "KometClient" or "Komet"

1. Status and relationships
1.1. "Komet" (the "App") is an unofficial third-party application and is not affiliated with Communication Platform LLC (rights holder of the "MAX" service).
1.2. The App developers are not partners, employees, or affiliates of Communication Platform LLC.
1.3. All references to the "MAX" trademarks and related services belong to their respective owners.

2. Terms of use
2.1. By using "Komet", you:
• Automatically agree to the official MAX User Agreement (https://legal.max.ru/ps)
• Understand that using an unofficial client may lead to your account being blocked by Communication Platform LLC
• Accept all risks associated with using the App
2.2. Strictly prohibited:
• Using "Komet" to distribute prohibited content
• Sending bulk messages (spam)
• Violating applicable law
• Attempting to hack or disrupt the original "MAX" service
2.3. The technical implementation follows fair-use principles and does not infringe the rights holder's exclusive rights under applicable interoperability and fair-use norms.
2.4. Technical interaction:
• "Komet" uses publicly available interaction methods with "MAX", similar to the web client (https://web.max.ru)
• Requests are made for interoperability purposes
• The developers do not circumvent technical protection measures or decompile the original software

3. Technical aspects
3.1. "Komet" uses only publicly available methods to interact with "MAX" through official endpoints.
3.2. Requests are made under fair use for interoperability.
3.3. The developers are not liable for:
• Changes to the original service API
• Account blocks
• Functional limitations caused by Communication Platform LLC

4. Privacy
4.1. "Komet" does not store or process users' personal data on developers' servers.
4.2. Authentication data is sent directly to Communication Platform LLC servers.
4.3. The developers do not have access to logins, passwords, chats, or other personal user data.

5. Liability and limitations
5.1. "Komet" is provided "as is" without warranties.
5.2. The developers may discontinue support at any time without notice.

6. Legal basis
6.1. Development and distribution of "Komet" are carried out with regard to interoperability, fair use, and publicly available information principles, including EU Directive 2019/790 on interoperability where applicable.
6.2. Interaction with "MAX" occurs only through:
• Public interfaces available via the web client
• Reverse engineering methods permitted for interoperability purposes where applicable by law
• Open interaction protocols not protected by technical protection measures
6.3. "Komet" does not circumvent technical protection measures or disrupt the normal operation of the original service.

7. Final provisions
7.1. By using "Komet", you agree that:
• The authorized way to use "MAX" is through official clients
• Service-related claims should be directed to Communication Platform LLC
• The App developers are not liable for any direct or indirect damages
7.2. These terms may change without prior notice.

8. Security and privacy features
8.1. "Komet" may include privacy tools:
• Session data substitution to reduce tracking via OSINT-style techniques
• Proxy connectivity for safer network access
• Reduced telemetry where applicable
8.2. These features:
• Aim to protect user privacy
• Are not intended to bypass the original service's security systems
• Are implemented with respect for privacy protections under applicable law
8.3. The developers are not liable for:
• Blocks related to privacy tools
• Service behavior when such features are enabled
8.4. Session export and import
8.4.1. "Komet" may allow exporting and importing session data for:
• Moving data between your devices
• Backing up credentials
• Restoring access if a device is lost
8.4.2. Implementation notes:
• Export may be decoupled from the phone number where technically possible
• Session data may be protected with a password and encryption (e.g. AES-256)
• Encryption keys are known only to you and are not stored by the developers
8.4.3. Technical approach:
• Export/import may use authorization tokens for service identification
• Session parameters may be adjusted to preserve authentication context
• Proxy settings may be included for a single connectivity configuration
• Imported sessions may route traffic according to your proxy settings
• The original service may not receive explicit device-change metadata beyond what the protocol normally sends
• Encryption may apply to the full exported package (session + proxy configuration)
8.4.4. Legal considerations:
• Processing is based on your consent where personal data laws require it
• Data minimization: only what is needed for operation
• Token use is not unauthorized access under applicable criminal computer-access laws
• Session handling is analogous to legitimate session persistence (e.g. cookies)
• IP masking can be a lawful way to protect personal data where applicable
8.4.5. Limitations:
• You are responsible for passwords and backups
• Developers cannot access your encrypted session exports
• Lost passwords cannot be recovered by design
• Encryption keys are not stored in the app and are known only to you
''';
