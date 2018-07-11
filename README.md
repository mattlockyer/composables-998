

# Composable Non-Fungible Tokens (CNFTs)

A WIP implementation and documentation repo for the ERC-998 standard extension to ERC-721 on the Ethereum blockchain.

Proposal: https://github.com/ethereum/EIPs/issues/998

Here is a high-level overview of the ERC998 standard: https://medium.com/@mudgen/top-down-and-bottom-up-composables-whats-the-difference-and-which-one-should-you-use-db939f6acf1d

Original Medium Post (code outdated): https://medium.com/coinmonks/introducing-crypto-composables-ee5701fde217

Discord and Discourse community: NFTy Magicians. Search Twitter for a link to join, or use this one: https://discord.gg/uxkHy3

## Getting Started

Clone the repo and run `npm i` then `truffle test`. You should see a number of tests passing.

The repo activity is mainly in `/contracts` and `/test`.

## Architecture and Design

CNFTs is intended to be a standard extension to ERC-721, the Non-Fungible Token standard for Ethereum.

As an extension, Composables are Non-Fungible Tokens (ERC-721) that can inherit from a standard interface the ability to own and manage other Non-Fungible Tokens (ERC-721) or Fungible Tokens (ERC-20), or both.

The flexibility of choosing specifically what token type you will need to own and manage with your tokens is intended to keep the contract size minimal and Application Binary Interface (ABI) clean and simple.

## Questions?

Discord and Discourse community: NFTy Magicians. Search Twitter for a link to join.

## ERC998 Contributors

Main project manager/coordinator/leader: Matt Lockyer, https://medium.com/@mattdlockyer

The current implementation of ERC998 was written by Nick Mudge <nick@perfectabstractions.com>, https://medium.com/@mudgen.

People who have helped with the standard and/or implementation:
* Nathalie Chan King Choy, https://github.com/nathalie-ckc
* Maciej Górski, https://github.com/mg6maciej
* Abhishek Chadha, https://medium.com/@abhishekchadha

