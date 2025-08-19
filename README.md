# DecoFreelance

A blockchain-powered decentralized freelance marketplace that addresses trust issues, high fees, and payment disputes in traditional platforms by enabling secure, transparent peer-to-peer transactions and community-driven governance — all on-chain using Clarity on the Stacks blockchain.

---

## Overview

DecoFreelance consists of four main smart contracts that together form a decentralized, transparent, and fair ecosystem for freelancers and clients:

1. **Job Posting Contract** – Manages the creation, bidding, and assignment of freelance jobs.
2. **Escrow Payment Contract** – Handles secure escrow for payments, releasing funds only upon verified completion.
3. **Reputation NFT Contract** – Issues and updates reputation NFTs based on job outcomes and reviews.
4. **Dispute DAO Contract** – Enables community voting to resolve disputes fairly and transparently.

---

## Features

- **Decentralized job listings** with open bidding and no platform fees  
- **Escrow-based payments** to ensure freelancers get paid and clients receive quality work  
- **Reputation NFTs** that build verifiable on-chain credentials for users  
- **DAO governance** for dispute resolution, reducing reliance on centralized arbitrators  
- **Transparent transaction history** for all jobs, payments, and resolutions  
- **Integration with oracles** for off-chain verification of work completion (e.g., via file uploads or milestones)  

---

## Smart Contracts

### Job Posting Contract
- Create and list freelance jobs with details like description, budget, and deadlines
- Handle bids from freelancers and selection by clients
- Track job status (open, assigned, in progress, completed)

### Escrow Payment Contract
- Lock funds in escrow upon job assignment
- Release payments based on milestones or full completion
- Refund mechanisms for cancellations or disputes

### Reputation NFT Contract
- Mint NFTs representing user reputation
- Update NFT metadata with ratings, completed jobs, and reviews
- Transferable or soulbound options for reputation portability

### Dispute DAO Contract
- Submit disputes with evidence from involved parties
- Token-weighted voting by community members
- Automated execution of resolutions (e.g., fund releases or penalties)

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started)
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/decofreelance.git
   ```
3. Run tests:
    ```bash
    npm test
    ```
4. Deploy contracts:
    ```bash
    clarinet deploy
    ```

## Usage

Each smart contract operates independently but integrates with others for a complete freelance marketplace experience.
Refer to individual contract documentation for function calls, parameters, and usage examples.

## License

MIT License