# Setup
You can find the dependencies here:\
https://github.com/dbechrd/jai-modules
> Note: Some of the modules are my own code, independent from Yojimbo, such as Trivial. I don't intend to make breaking changes, but if I accidentally do, please open an issue.

# Usage
For basic usage, please refer to the C++ examples here:\
https://github.com/mas-bandwidth/yojimbo/blob/main/USAGE.md

# Security
For security information, please refer to:\
https://github.com/mas-bandwidth/yojimbo/blob/main/USAGE.md

> [!WARNING]
> Encryption is disabled by default!
>
> Encryption has been stubbed out in this port, to remove the libsodium dependency. The source repository (C++ Yojimbo from Glenn) has vendor libsodium into a local directory and pruned it greatly, while still attempting to track the upstream for critical bug fixes. This repository, does not attempt to vendor libsodium, nor track the upstream of any of the source repositories. As such, critical bug fixes may be missing in the Yojimbo code, or any of its dependencies (Reliable, Netcode, Serialize). If you want to use encryption (which you should definitely want, in any production use-case), it should be fairly easy to find/generate Jai bindings for libsodium and inject that dependency into the placeholder procedures that currently print warning messages to the console about "FAKE ENCRYPTION". They are only called in four places, all of which are right next to each other in the code (two are stubbed out completely and aliased, please read the comments carefully).
