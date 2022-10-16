## PBT (Physical Backed Token)

NFT collectors enjoy collecting digital assets and sharing them with others online. However, there is currently no such standard for showcasing physical assets as NFTs with verified authenticity and ownership. Existing solutions are fragmented and tend to be susceptible to at least one of the following:
- The NFT cannot proxy as ownership of the physical item. In most current implementations, the NFT and physical item are functionally two decoupled distinct assets after the NFT mint, in which the NFT can be freely traded independently from the physical item.

- Verification of authenticity of the physical item requires action from a trusted entity (e.g. StockX).

PBT aims to mitigate these issues in a decentralized way through a new token standard (an extension of EIP-721).

From the [Azuki](https://twitter.com/AzukiOfficial) team. **Chiru Labs is not liable for any outcomes as a result of using PBT**, DYOR. Repo still in beta.

[pbt.io](https://www.pbt.io/) | [EIP](https://www.pbt.io/) | [Blog](https://www.pbt.io/)  <--- (TODO: update these urls)

## How does it work?

#### Requirements

This approach assumes that the physical item must have a chip attached to it that fulfills the following requirements ([Kong](https://arx.org/) is one such vendor for these chips):

- the ability to securely generate and store an ECDSA secp256k1 asymmetric keypair
- the ability to sign messages from the private key of the asymmetric keypair
- the ability for one to retrieve the public key of the asymmetric keypair

The approach also requires that the contract uses an account-bound implementation of EIP-721 (where all EIP-721 functions that transfer must throw, e.g. the "read only NFT registry" implementation referenced in EIP-721). This ensures that ownership of the physical item is required to initiate transfers and manage ownership of the NFT, through a new function introduced in this interface described below.

#### Approach

On a high level:
- Each NFT is conceptually linked to a physical chip.
- The NFT can only be transferred to a different owner if a signature from the chip is supplied to the contract.
- This guarantees that a token cannot be transferred without consent from the owner of the physical item.

More details available in the [EIP](https://www.pbt.io/) and inlined into `IPBT.sol`. Feel free to contact [@2pmflow](https://twitter.com/2pmflow) if you have any questions.

^ TODO: update EIP URL

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

#### Running tests locally

1. `npm install`
2. `npm run test`

<!-- LICENSE -->

## License

Distributed under the MIT License.
