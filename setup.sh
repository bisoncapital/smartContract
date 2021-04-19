#!/usr/bin/env bash

# Deploy contracts
truffle migrate --reset --network bsc --skipDryRun

# Verify Contracts on Etherscan
truffle run verify LockUpPool --network bsc --license SPDX-License-Identifier

truffle-export-abi
