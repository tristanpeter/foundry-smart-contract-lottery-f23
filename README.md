# Proveably random raffle contracts

## About

This code is to create a proveably random smart contract lottery.

## What do we want it to do?

1. Users can enter by paying for a ticket.
    1. The ticket fees are going to go to the winner during the draw
2. After x period of time, the lottery will automatically draw a winner.
    1. This will be done programatically.
3. We will be using Chainlink VRF and Chainlink Automation to do this.
    1. Chainlink VRF -> Randomness
    2. Chainlink Automation -> Time-based trigger

## Tests

1. Write some deploy scripts
2. Write out tests so that...
    1. It works on a local chain
    2. It works on a forked Testnet
    3. It works on a forked Mainnet