

# Composable Non-Fungible Tokens (cNFTs)

An implementation and documentation repo for the ERC-998 standard extension to ERC-721 on the Ethereum blockchain.  The purpose of this repo is to see the theory in action, to gather insights and feedback on the ERC-998 standard and to provide a working implementation of ERC998 that people can use.

Draft EIP 998: 
https://github.com/ethereum/EIPs/blob/master/EIPS/eip-998.md

Here is a high-level overview of the ERC-998 standard: <br/>
https://medium.com/@mudgen/top-down-and-bottom-up-composables-whats-the-difference-and-which-one-should-you-use-db939f6acf1d

Discord and Discourse community: NFTy Magicians. <br/>
https://discordapp.com/invite/3TtqP2C <br/>
https://nftymagicians.org/

Original Medium Post (code outdated): <br/>
https://medium.com/coinmonks/introducing-crypto-composables-ee5701fde217

Some follow-on Medium posts describing progress on the project: <br/>
https://medium.com/coinmonks/crypto-composables-erc-998-update-6-in-the-wild-6ece410d263d
https://medium.com/coinmonks/crypto-composables-erc-998-update-5-eb0a748a9889
https://hackernoon.com/crypto-composables-erc-998-update-4-the-namening-7a05d28f3401 <br/>
https://medium.com/coinmonks/crypto-composables-erc-998-update-3-first-contact-f3930a08636 <br/>
https://medium.com/coinmonks/crypto-composables-erc-998-update-2-4b160df79836 <br/>
https://medium.com/coinmonks/crypto-composables-erc-998-update-1cc437c13664 <br/>

## Getting Started

Clone the repo and run `npm i` then `truffle test`. You should see a number of tests passing.

The repo activity is mainly in `/contracts` and `/test`.

## Architecture and Design

cNFTs is intended to be a standard extension to ERC-721, the Non-Fungible Token standard for Ethereum.

As an extension, Composables are Non-Fungible Tokens (ERC-721) that can inherit from a standard interface the ability to own and manage other Non-Fungible Tokens (ERC-721) or Fungible Tokens (ERC-20), or both.

The flexibility of choosing specifically what token type you will need to own and manage with your tokens is intended to keep the contract size minimal and Application Binary Interface (ABI) clean and simple.

## Questions?

Go to our Discord and Discourse community: NFTy Magicians. See above for links.

## ERC998 Contributors

Matt Lockyer started the ERC998 standard and developed the initial ideas and the initial implementation of ERC998. Matt Lockyer https://medium.com/@mattdlockyer

Main project manager/coordinator/leader: Nick Mudge <nick@mokens.io>, https://twitter.com/mudgen

The current implementation of ERC998 was written by Nick Mudge

People who have helped with the standard and/or implementation:
* Nathalie Chan King Choy, https://github.com/nathalie-ckc
* Maciej Górski, https://github.com/mg6maciej
* Abhishek Chadha, https://medium.com/@abhishekchadha
* Jordan Schalm <jordan.schalm@gmail.com>
