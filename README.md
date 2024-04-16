# StakeNS

State: Rough but working.  

StakeNS is a voting-based naming system for Arweave, powered by AO. To begin, send (AOCRED-Test) tokens to the StakeNS process's pid. Then, utilize these tokens to vote for who should control what name by staking credits. Stakes are reclaimable, allowing you to change your mind and withdraw tokens from the process.  

The idea is stolen from how community URLs in LBRY protocol work, for details see: https://lbry.com/faq/naming and https://tech.lbry.nu/spec#appendix  

# Simple UI
Simple UI for StakeNS process can be found from here https://arweave.net/dTBZWiafcjFLd4-FvkQl5FOfRHl0djXLEgz8OU3IlVM/  
#### Short steps to help you get started:
1. Send some CREDs to your wallet connected to the page
2. Send some of the CREDs to the process using the option on the page
3. Create a record for a name you want, and test out the results at https://jees.site/ (Naming works similar to ArNS, like `https://name.jees.site/`)  
*Note:*  
https://jees.site/ should also have required header set for it to work with a gateway node, and can be used by changing the `TRUSTED_ARNS_GATEWAY_URL="https://__NAME__.arweave.dev"` to `TRUSTED_ARNS_GATEWAY_URL="https://__NAME__.jees.site"` in .env file. (I think)


# Brief overview of the usage:

#### Creating a record for a name and connecting a txid
1. Send some CREDs to the StakeNS process, using the `Transfer` action in the CRED process. (Don't use `Cast` tag, or tokens will get stuck to the process)
2. Use `CreateNameRecord` to create a record for the name, and to stake some CREDs for it, and to set what txid it should direct to.

#### Taking over the control of a record
1. Find out that the name you want is already taken by someone else.  
2. Stake more tokens to it than they have using the `CreateStake` action
   - Each stake has an activation delay. Activation delay is based on the time the current holder has held the control over the record. For each block passed, the new stakes will have an additional block of an activation delay, capping at 5040 blocks(~7 days).
   - You can also stake tokens on someone else's behalf, to help them to takeover the control.
1. Wait for your stake to activate and call `ResolveNewRecordHolder` to trigger a takeover.
1. Update the record to point to the txid you want with the `UpdateNameRecord` action

#### Getting CREDs back from the process
1. Use `RetrieveState` state to get the state for the process, and find ids of your stakes. (Decode the json value from the `State` tag in response, and look for your stakes in there. `Stakes[your-address][staked-recordname]`)
1. Use `ReclaimStake` to revoke some of your stakes and get the CREDs available for staking elsewhere or for withdrawing.
2. Use `Withdraw` to tell process to send you back a specified quantity of your CREDs



# Process actions:
  
#### StakeNS
```
StakeNS = "98x5osvP4pTIDNfqbMl7UphYzSR9ai2WPxeQ7YXeXA4"
```
#### Sending AOCRED-Test tokens to use for staking
    
```
TokenPid = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Send({ Target = TokenPid, Action = "Transfer", Quantity = "10", Recipient = StakeNS })
```
  
#### CreateNameRecord
  
```
Send({ Target = StakeNS, Action = "CreateNameRecord", RecordName = "Name", StakeQty = "10",  TargetTxid = "txid-to-content", UndernamesTxid = "txid-to-json-containing-undernames" })
```
`UndernamesTxid` is optional.
  
#### UpdateNameRecord
  
```
Send({ Target = StakeNS, Action = "UpdateNameRecord", TargetTxid = "txid-to-content", UndernamesTxid = "txid-to-json-containing-undernames" })
```
Only one of the `TargetTxid` or `UndernamesTxid` is required.
  
#### CreateStake
  
```
Send({ Target = StakeNS, Action = "CreateStake", RecordName = "Name", StakeQty = "10", Beneficier = "address-of-the-beneficier" })
```
`Beneficier` is optional, by default it will be set to the sender.

#### ReclaimStake
  
```
Send({ Target = StakeNS, Action = "ReclaimStake", RecordName = "Name", StakeId = "stakeID" })
```

#### ResolveNewRecordHolder
  
```
Send({ Target = StakeNS, Action = "ResolveNewRecordHolder", RecordName = "Name" })
```

#### Withdraw
  
```
Send({ Target = StakeNS, Action = "Withdraw", Quantity = "10" })
```

#### RetrieveState
```
Send({ Target = StakeNS, Action = "RetrieveState"})
```

# Undernames
Name records on StakeNS can have undernames, similar to how ArNS has undernames. Undernames are to be stored in a json file uploaded to Arweave, and its txid can be linked to the name record.  
  
Format for the undernames json:  
```
{
   "version": "0.1.1",
   "undernames": [
      { "name": "undername", "txid": "content-txid" },
      ...
   ]
}
```
