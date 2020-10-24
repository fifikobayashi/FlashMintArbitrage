# Flash Mint Arbitrage

An example of a Flash Mint powered arbitrage executed on the Ropsten testnet between a flash mint DEX, Kyber and Uniswap.

![](https://github.com/fifikobayashi/FlashMintArbitrage/blob/main/img/pepe.jpg)

- [Background](https://github.com/fifikobayashi/FlashMintArbitrage#background)
- [TLDR](https://github.com/fifikobayashi/FlashMintArbitrage#tldr)
- [FAQ](https://github.com/fifikobayashi/FlashMintArbitrage#faq)
- [Setup and Execution](https://github.com/fifikobayashi/FlashMintArbitrage#setup-and-execution)
- [Next Steps](https://github.com/fifikobayashi/FlashMintArbitrage#next-steps)


## Background
When I first heard about Flash Minting back in Feb 2020 I laughed. Then when I heard about Maker's MIP25 for a flash mint DAI module, I laughed again. But the more I started looking into ways this concept can be gamed, the more I realised the underlying tokenomics actually work. Because at the end of the atomic Tx, no party is out of pocket.

So I forked Austin William's [Flash Mint implementation](https://github.com/Austin-Williams/flash-mintable-tokens) onto Ropsten, along with a Flash Mint compatible DEX and executed a Flash Mint powered arbitrage between FlashMint DEX, Kyber and Uniswap.

The following contracts are on Ropsten:
- Flash WETH [0xD4f239B1be6a0bdCf7e150AB1E43b453e101EF5a](https://ropsten.etherscan.io/address/0xD4f239B1be6a0bdCf7e150AB1E43b453e101EF5a)
- Flash Mint DEX [0x0D8F5aB7A0f5aA16a9bAAc38205f3E39855486eB](https://ropsten.etherscan.io/address/0x0D8F5aB7A0f5aA16a9bAAc38205f3E39855486eB)
- Flash Mint Demo [0x65882EC2b8d5214331bd43e67c801C6EE65E67b3](https://ropsten.etherscan.io/address/0x65882EC2b8d5214331bd43e67c801C6EE65E67b3)

If this all sounds Greek to you, head over to Austin's [Flash Mint presentation](https://zoom.us/rec/play/vpUsd-2uqG83H4KV4wSDV_QqW9W8eq6sgyYa__dbyxmxU3JQZlGgNOQWa7YCcdGL7KuPjJmmffLXrHeV?continueMode=true&_x_zm_rtaid=bOcPBuGvSXKBX4e8HeUYmA.1586903684079.752b46c2abd76976551dd088fa79a2a9&_x_zm_rhtaid=116) which explains this concept in detail. 

## TLDR
If you just want my TLDR summary, here is what the code is achieving:

![](https://github.com/fifikobayashi/FlashMintArbitrage/blob/main/img/ExecutionSnapshot.PNG)

![](https://github.com/fifikobayashi/FlashMintArbitrage/blob/main/img/EndStateSnapshot.PNG)



## FAQ

***How is Flash Minting different to Flash Loans?***

Flash Minting is similar to Flash Loans where you don't need any up front capital to access temporary liquidity within an atomic transaction.
The difference is you don't flash borrow from a liquidity pool, the tokens are independently minted for your use during the flash mint tx and the same amount of tokens must be burned at the end of the transaction otherwise your transaction will revert like a flash loan.

***Isn't the Flash Mint DEX now rekt because it's left holding a bag of valueless Flash WETH!***

At the end of the Tx the 1 Flash WETH that the Flash Mint DEX is holding is actually backed by 1 ETH in the Flash WETH contract. They can call the Flash WETH contract to redeem the underlying ETH.

***What if another Flash Mint Demo contract takes the 1 ETH sitting in the Flash WETH contract, doesn't that mean the x Flash WETH held by the Flash Mint DEX is no longer backed?***

For anyone to hold Flash WETH, they needed to be flash minted at some point, which meants the same amount of Flash WETH needs to be burned at the end of that Tx.

If another contract executes a flash mint, then uses x flash WETH to redeem for x ETH sitting in the FlashWETH contract, and if they do nothing else their flash mint Tx will revert like a flash loan because they no longer have the same amount of originally minted Flash WETH to burn in order to successfully close the Flash Mint Tx. However as Austin Williams explained in his presentation, this is still an experimental concept and there are bound to be exploits afoot. Don't use this in prod without a thorough and holistic audit on how this impacts your whole ecosystem.

***What if, during the atomic Tx, something breaks AFTER the Flash Mint DEX accepted the 1 Flash WETH and gave out 1 ETH?***

The whole end to end transaction reverts, so it never actually accepted the Flash WETH to begin with, much like a flash loan reversion.

***This is too dangerous, if this makes it to mainnet it'll be Q1 2020 all over again with the flash loan exploits!***

There might be some short term pain as people will inevitably try to game the concept but I personally see this as a net positive long term for the DeFi ecosystem as it will reduce the amount of projects that treat security audits as an afterthought. Flash loans were at one stage considered too hazardous, but now you see users regularly flashing 8 figure DAI loans for breakfast.

***What's the maximum number of tokens I can flash mint?***

Anyone can mint up to 2^256-1 WETH, unless additional restrictions are set by the flash mint provider. The [folks behind WETH10](https://twitter.com/acuestacanada/status/1319581439831298048) deployed their flash mint powered WETH10 onto the testnet with no restrictions so would be interesting to see if anything comes up from testing that necessitates a mint size restriction.

***Can you build a version of this for me that makes me money?***

To quote Hamlet Act III Scene III line 92........."no".



## Setup and Execution

These contracts are Remix friendly so you can just plonk them directly on there, set compiler to sol ^0.5.16 and not have to worry about all the dependencies.

1. Deploy FlashWETH.sol

2. Update the Flash WETH address in FlashMintDex.sol
```
address constant public fWETH = 0xD4f239B1be6a0bdCf7e150AB1E43b453e101EF5a;
```
3. Deploy FlashMintDex.sol

4. Update the IExchange address in FlashMintDemo.sol with the FlashMintDex address
```
IExchange public exchange = IExchange(0x0D8F5aB7A0f5aA16a9bAAc38205f3E39855486eB);
```

5. Deploy FlashMintDex.sol

6. Provide some liquidity to FlashMintDex e.g. send 1 ether to it so users can swap 1 Flash WETH for 1 ETH

7. Provide some funds to your FlashMintDemo contract e.g. send 2 ether to it.

8. Now let's flash mint arb! Call FlashMintDemo's beginFlashMint() with the following paramters
```
_mintAmount: 1000000000000000000 // flash minting 1 ETH worth of Flash WETH (i.e. 1 Flash WETH)
_flashMintContract: the address of your FlashMintDemo contract so arb profits and remaining balance go back there.
_srcQtyKyber: 1000000000000000000 // trading 1 ETH on kyber for DAI
_erc20UniTrade: 579000000000000000000 // trading 579 DAI on Uniswap back to ETH
```

9. Go make some tea, sit back and watch the magic happen.

10. A successful flash mint arb tx will look like [this](https://ropsten.etherscan.io/tx/0xcd7df11739852523b70419f6868d2c43fd57e984c160911d5da962d3d2e2db14).

## Next Steps
There's a broader discussion needed on whether this type of concept should involve fees. I'd imagine existing flash lending protocols would not be too excited about a zero fee Flash Minting module as it would take business away from their existing flash loan lending pools. 

At the same time, from a consumer POV, I don't know how much it'd cost the lenders to allow flash minting out of thin air, other than the intense audits needed to assure the integrity of their ecosystem when introducing flash minting on mainnet.
And as mentioned earlier this is still an experimental concept so would be great to hear all the ways this can be exploited.

Food for thought.

<br /><br />
If you found this useful and would like to send me some gas money: 
```
0xef03254aBC88C81Cb822b5E4DCDf22D55645bCe6
```
Or if you're short on gas money just send me some Ropsten Ether so I can play with this at scale.



Thanks,
@fifikobayashi
