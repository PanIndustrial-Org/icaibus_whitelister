# ICaiBus Whitelister

**This is alpha software. Use at your own risk.**

**Repository:** [Pan Industrial Org - ICaiBus Whitelister](https://github.com/PanIndustrial-Org/icaibus_whitelister)

---

## Overview

**ICaiBus Whitelister** is part of the broader ICaiBus messaging bus ecosystem for the Internet Computer (IC), which enables decentralized publish-subscribe messaging patterns across canisters. This repository contains a Motoko-based implementation of a whitelisting mechanism for event-driven pub-sub systems. It supports managing access control and secure subscription configurations.

This project uses [ICRC-72 - Minimal Event-Driven Pub-Sub Standard](https://github.com/icdevs/ICEventsWG/blob/main/draft_proposals_current/candidate-ICRC72-20240924.md) and [ICRC-75 - Minimal Membership Standard](https://github.com/dfinity/ICRC/issues/75).

With this Minimal Event-Driven Pub-Sub Standard, designed to formalize event messaging patterns on the IC. By leveraging whitelister functionality, developers can:

- Manage access control for specific event namespaces.
- Provide whitelisted event notifications to authorized subscribers.
- Enable fine-grained control over event handling and filtering.

---

## Project Components

### Canisters

This repository contains two main canisters:

1. **Whitelister** (`src/whitelister.mo`):
   - Implements the whitelisting logic for managing event subscriptions.
   - Provides methods for adding, removing, and querying whitelisted subscribers.
   - Conforms to the ICRC-72 standards for event handling and subscription management.

2. **Splitter** (`src/splitter.mo`):
   - A utility canister that helps manage the distribution of events across multiple subscribers.
   - Handles splitting event streams and forwarding them to whitelisted subscribers.

Both canisters are built using Motoko and interact seamlessly with other ICaiBus components, such as orchestrators and broadcasters.

### Configuration

The project uses `dfx.json` to define the canister configuration:

```json
{
  "canisters": {
    "whitelister": {
      "main": "src/whitelister.mo",
      "type": "motoko"
    },
    "splitter": {
      "main": "src/splitter.mo",
      "type": "motoko"
    }
  },
  "defaults": {
    "build": {
      "args": "",
      "packtool": "mops sources"
    },
    "replica": {
      "subnet_type": "system"
    }
  },
  "version": 1
}
```

---

## Features

### Whitelister Canister
- Add and remove whitelisted subscribers dynamically.
- Query subscription details for managing event access.
- Enforce namespace-specific access controls.

### Splitter Canister
- Distribute event notifications across multiple subscribers efficiently.
- Apply subscription-specific configurations like filters and priorities.

---

## Setup and Installation

### Prerequisites
- [DFX SDK](https://internetcomputer.org/docs/current/developer-docs/build/install) installed.
- [Motoko Base Library](https://github.com/dfinity/motoko-base).

### Clone the Repository
```bash
git clone git@github.com:PanIndustrial-Org/ICaiBus_whitelister.git
cd icaibus_whitelister
```

## Workspace

You will need the subscriber component in your workspace.
---


## Contributing

We welcome contributions! Please follow these steps:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request describing your changes.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

## Contact

For questions or support, please reach out via:
- GitHub Discussions: [ICRC Discussions](https://github.com/icdevs/ICEventsWG/issues)
- Pan Industrial: [Contact Us](https://panindustrial.com)

---

## Acknowledgments

This project is part of the ICaiBus ecosystem and supported by the ICRC-72 standard. Special thanks to contributors and the Event Utility Working Group for their invaluable input.

