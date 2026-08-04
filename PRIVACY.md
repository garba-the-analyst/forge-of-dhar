# Privacy Policy

**Last Updated:** August 2026

The Dhar Programming Language respects the absolute privacy and sovereignty of the developer. This Privacy Policy outlines our data practices regarding the Dhar compiler executable and its associated repositories.

## 1. Zero Telemetry
The Dhar compiler (including "The Forge" and "Honing Dhar" environments) is a 100% offline, standalone systems tool. 
*   **No Data Collection:** The compiler does not collect, record, or transmit user data, keystrokes, source code, or IP addresses.
*   **No Telemetry:** There are no background analytics, crash reporting daemons, or "phone home" mechanisms embedded in the official compiler. Your code remains entirely on your local machine.

## 2. Local File Execution
The compiler requires access to your local filesystem strictly to open (`sys_open`), read (`sys_read`), and output compiled machine code (`output.asm`). It does not scan or access directories outside of the explicitly provided source path.

## 3. GitHub and Third-Party Infrastructure
While the compiler itself collects no data, interaction with the official GitHub repository is subject to GitHub's standard Privacy Statement. GitHub may collect metadata (such as IP addresses, commit histories, and account details) when you clone, fork, or submit issues to the repository.

## 4. Policy Changes
As Dhar expands into web and mobile backends, any future modules or package managers requiring network access will be strictly opt-in and accompanied by an updated privacy addendum.

## 5. Contact
For security disclosures or privacy inquiries, please open an issue on the official GitHub repository.