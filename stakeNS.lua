local json = require('json')

NameRecords = NameRecords or {}
Balances = Balances or {}
Stakes = Stakes or {}
tokenPid = 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc'

function isArweaveTxidOrAddress(text)
    local arweaveTxidOrAddressCharRe = "[%w_-]"
	return type(text) == 'string' and string.match(text, "^" .. arweaveTxidOrAddressCharRe:rep(43) .. "$") ~= nil; 
end

function Man ()
    return string.format([[
    
    # StakeNS:
  
    Voting based naming system for Arweave. Send AOCRED-Test tokens to process's pid, and stake them to vote for who should control each name.
    Stakes are reclaimable so you can always change your mind, and also withdraw the tokens back from the process.

    ## StakeNS
  
    `StakeNS = "%s"`

    ## Sending AOCRED-Test tokens to use for staking
    
    ```
    TokenPid = "%s"
    Send({ Target = TokenPid, Action = "Transfer", Quantity = "10", Recipient = StakeNS })
    ```
  
    ## CreateNameRecord
  
    ```
    Send({ Target = StakeNS, Action = "CreateNameRecord", RecordName = "Name", StakeQty = "10",  TargetTxid = "txid-to-content", UndernamesTxid = "txid-to-json-containing-undernames" })
    ```
    `UndernamesTxid` is optional.
  
    ## UpdateNameRecord
  
    ```
    Send({ Target = StakeNS, Action = "UpdateNameRecord", TargetTxid = "txid-to-content", UndernamesTxid = "txid-to-json-containing-undernames" })
    ```
    Only one of the `TargetTxid` or `UndernamesTxid` is required.
  
    ## CreateStake
  
    ```
    Send({ Target = StakeNS, Action = "CreateStake", RecordName = "Name", StakeQty = "10", Beneficier = "address-of-the-beneficier" })
    ```
    `Beneficier` is optional, by default it will be set to the sender.

    ## ReclaimStake
  
    ```
    Send({ Target = StakeNS, Action = "ReclaimStake", RecordName = "Name", StakeId = "stakeID" })
    ```

    ## ResolveNewRecordHolder
  
    ```
    Send({ Target = StakeNS, Action = "ResolveNewRecordHolder", RecordName = "Name" })
    ```

    ## Withdraw
  
    ```
    Send({ Target = StakeNS, Action = "Withdraw", Quantity = "10" })
    ```
  
  ]], ao.id, tokenPid)
end

--------------------------------
Handlers.add(
    "storeStakeInfo",
    function(m)
        return m.Action == "Credit-Notice" and m.From == tokenPid
    end,
    function (m)
        if not Balances[m.Sender] then Balances[m.Sender] = { available = 0, staked = 0 } end
        Balances[m.Sender].available = Balances[m.Sender].available + tonumber(m.Quantity)
    end
)
--------------------------------
Handlers.add(
    "RetrieveState",
    Handlers.utils.hasMatchingTag("Action", "RetrieveState"),
    function (m)
        print("Retrieve state")
        local state = {
            nameRecords = NameRecords,
            balances = Balances,
            stakes = Stakes,
            tokenPid = tokenPid,
        }
        
        ao.send({
            Target = m.From,
            State = json.encode(state)
        })
    end
)
---------------------
function createNameRecord(m)
    assert(type(m.RecordName) == 'string' and string.match(m.RecordName, "^[a-zA-Z0-9-]+$"),
        'name is required, and must match "^[a-zA-Z0-9-]+$"')
    local name = string.lower(m.RecordName)
    assert(isArweaveTxidOrAddress(m.TargetTxid),
        'TargetTxid is required, and must be a Arweave txid')
    assert(m.UndernamesTxid == nil or isArweaveTxidOrAddress(m.UndernamesTxid),
        'UndernamesTxid must be a Arweave txid')
    assert(NameRecords[name] == nil,
        'Record for name ' .. name .. ' already exists')

    if not Balances[m.From] then Balances[m.From] = { available = 0, staked = 0 } end
    local qty = math.floor(tonumber(m.StakeQty))
    assert(type(qty) == 'number' and qty > 0,
        'StakeQty must be a number, and larger than 0')
    assert(qty <= Balances[m.From].available,
        'Insufficient available funds: ' .. Balances[m.From].available)


    if not Stakes[m.From] then Stakes[m.From] = {} end

    Stakes[m.From][name] = {
        [m.Id] = {
            beneficiary = m.From,
            qty = qty,
            activationHeight = tonumber(m["Block-Height"])
        }
    }

    Balances[m.From].available = Balances[m.From].available - qty
    Balances[m.From].staked = Balances[m.From].staked + qty

    NameRecords[name] = {
        targetTxid = m.TargetTxid,
        undernamesTxid = m.UndernamesTxid,
        holder = m.From,
        lastTakeOverHeight = tonumber(m["Block-Height"]),
        stakers = {
            [m.From] = true,
        },
    }
    print("Record for name " .. m.RecordName .. " created")
end

Handlers.add(
    "createNameRecord",
    Handlers.utils.hasMatchingTag("Action", "CreateNameRecord"),
    function (m)
        local status, err = pcall(createNameRecord, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'CreateNameRecord-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'CreateNameRecord-Response', Response = "Record for name " .. m.RecordName .. " created" }
            })
        end
    end
)
--------------------------------
function updateNameRecord(m)
    assert(type(m.RecordName) == 'string' and string.match(m.RecordName, "^[a-zA-Z0-9-]+$"),
        'name is required, and must match "^[a-zA-Z0-9-]+$"')
    local name = string.lower(m.RecordName)
    assert(NameRecords[name] ~= nil,
        'Record for name ' .. name .. ' doesn\'t exists')
    assert(m.From == NameRecords[name].holder,
        'Only current holder is allowed to edit')
    assert(m.TargetTxid == nil or m.TargetTxid == "" or isArweaveTxidOrAddress(m.TargetTxid),
        'TargetTxid must be a Arweave txid')
    assert(m.UndernamesTxid == nil or m.UndernamesTxid == "" or isArweaveTxidOrAddress(m.UndernamesTxid),
        'UndernamesTxid must be a Arweave txid')

    NameRecords[name].targetTxid = m.TargetTxid or NameRecords[m.RecordName].TargetTxid
    NameRecords[name].undernamesTxid = m.UndernamesTxid or NameRecords[m.RecordName].UndernamesTxid

    print("Record updated")
end

Handlers.add(
    "updateNameRecord",
    Handlers.utils.hasMatchingTag("Action", "UpdateNameRecord"),
    function (m)
        local status, err = pcall(updateNameRecord, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'UpdateNameRecord-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'UpdateNameRecord-Response', Response = "Record for name " .. m.RecordName .. " updated successfully" }
            })
        end
    end
)
--------------------------------
function createStake(m)
    assert(type(m.RecordName) == 'string' and string.match(m.RecordName, "^[a-zA-Z0-9-]+$"),
        'name is required, and must match "^[a-zA-Z0-9-]+$"')
    local name = string.lower(m.RecordName)
    assert(NameRecords[name] ~= nil,
        'Record for name ' .. name .. ' doesn\'t exists')
    assert(m.Beneficiary == nil or isArweaveTxidOrAddress(m.Beneficiary),
        'Beneficiary must be a Arweave address')
    if m.Beneficiary == nil then m.Beneficiary = m.From end

    if not Balances[m.From] then Balances[m.From] = { available = 0, staked = 0 } end
    local qty = math.floor(tonumber(m.StakeQty))
    assert(type(qty) == 'number' and qty > 0,
        'StakeQty must be a number, and larger than 0')
    assert(qty <= Balances[m.From].available,
        'Insufficient available funds: ' .. Balances[m.From].available)

    if not Stakes[m.From] then Stakes[m.From] = {} end
    if not Stakes[m.From][name] then Stakes[m.From][name] = {} end
    if not NameRecords[name].stakers then NameRecords[name].stakers = {} end

    local isBeneficiaryHolder = m.Beneficiary == NameRecords[name].holder
    local blocksInDay = 720;
	local maxActivationDelay = 7 * blocksInDay;
	local currentHeight = tonumber(m["Block-Height"]);
	local currentActivationDelay = math.min(currentHeight - NameRecords[name].lastTakeOverHeight, maxActivationDelay);
	local activationHeight = isBeneficiaryHolder and currentHeight or currentHeight + currentActivationDelay;

    Stakes[m.From][name][m.Id] = {
        beneficiary = m.Beneficiary,
        qty = qty,
        activationHeight = activationHeight
    }
    
    Balances[m.From].available = Balances[m.From].available - qty
    Balances[m.From].staked = Balances[m.From].staked + qty

    NameRecords[name].stakers[m.From] = true

    print("Stake created")
end

Handlers.add(
    "createStake",
    Handlers.utils.hasMatchingTag("Action", "CreateStake"),
    function (m)
        local status, err = pcall(createStake, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'CreateStake-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'CreateStake-Response', Response = m.StakeQty .. " staked for name " .. m.RecordName .. " successfully"}
            })
        end
    end
)
--------------------------------
function reclaimStake(m)
    assert(type(m.RecordName) == 'string' and string.match(m.RecordName, "^[a-zA-Z0-9-]+$"),
        'name is required, and must match "^[a-zA-Z0-9-]+$"')
    local name = string.lower(m.RecordName)
    assert(isArweaveTxidOrAddress(m.StakeId),
        'StakeId must be a Arweave txid')
    assert(Stakes[m.From][name] ~= nil and Stakes[m.From][name][m.StakeId] ~= nil,
        'Stake ' .. m.StakeId .. ' not found for the record "' .. name .. '" from pid ' .. m.From)

    local stake = Stakes[m.From][name][m.StakeId]
    Stakes[m.From][name][m.StakeId] = nil
    Balances[m.From].available = Balances[m.From].available + stake.qty
    Balances[m.From].staked = Balances[m.From].staked - stake.qty

    -- Clear empty entries
    if next(Stakes[m.From][name]) == nil then
        Stakes[m.From][name] = nil
        NameRecords[name].stakers[m.From] = nil
    end
    if next(Stakes[m.From]) == nil then Stakes[m.From] = nil end
    if next(NameRecords[name].stakers) == nil then NameRecords[name] = nil end

    print("Stake reclaimed")
end

Handlers.add(
    "reclaimStake",
    Handlers.utils.hasMatchingTag("Action", "ReclaimStake"),
    function (m)
        local status, err = pcall(reclaimStake, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'ReclaimStake-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'ReclaimStake-Response', Response = "Stake reclaimed successfully" }
            })
        end
    end
)
--------------------------------
function withdraw(m)
    if not Balances[m.From] then Balances[m.From] = { available = 0, staked = 0 } end
    local qty = math.floor(tonumber(m.Quantity))
    assert(type(qty) == 'number' and qty > 0,
        'Quantity must be a number, and larger than 0')
    assert(qty <= Balances[m.From].available,
        'Insufficient available funds: ' .. Balances[m.From].available)

    ao.send({
        Target = tokenPid,
        Action = "Transfer",
        Recipient = m.From,
        Quantity = tostring(qty),
    })

    Balances[m.From].available = Balances[m.From].available - qty
    if Balances[m.From].available == 0 and Balances[m.From].staked == 0 then Balances[m.From] = nil end
    
    print("Tokens withdrawn")
end

Handlers.add(
    "withdraw",
    Handlers.utils.hasMatchingTag("Action", "Withdraw"),
    function (m)
        local status, err = pcall(withdraw, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'Withdraw-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'Withdraw-Response', Response = m.Quantity .. " tokens withdrawn successfully" }
            })
        end
    end
)
--------------------------------
function resolveNewRecordHolder(m)
    assert(type(m.RecordName) == 'string' and string.match(m.RecordName, "^[a-zA-Z0-9-]+$"),
        'name is required, and must match "^[a-zA-Z0-9-]+$"')
    local name = string.lower(m.RecordName)
    assert(NameRecords[name] ~= nil,
        'Record for name ' .. name .. ' doesn\'t exists')

    local participants = {}
    local isHolderParticipating = false
    for staker, _ in pairs(NameRecords[name].stakers) do
        for _, stake in pairs(Stakes[staker][name]) do
            if stake.beneficiary == NameRecords[name].holder then
                isHolderParticipating = true
            end
            if participants[stake.beneficiary] == nil then
                participants[stake.beneficiary] = { totalQty = 0, activeQty = 0 }
            end
            
            participants[stake.beneficiary].totalQty = participants[stake.beneficiary].totalQty + stake.qty
            
            if m['Block-Height'] >= stake.activationHeight then
                participants[stake.beneficiary].activeQty = participants[stake.beneficiary].activeQty + stake.qty
            end
        end
    end

    local highestActiveQty = 0;
	local highestActiveStaker = nil;
	local highestTotalQty = 0;
	local highestTotalStaker = nil;

    for k, v in pairs(participants) do
        if v.activeQty > highestActiveQty then
            highestActiveQty = v.activeQty
            highestActiveStaker = k
        end
        if v.totalQty > highestTotalQty then
			highestTotalQty = v.totalQty;
			highestTotalStaker = k;
		end
    end
   
    local takeOverTriggered = not isHolderParticipating or highestActiveStaker ~= NameRecords[name].holder;
	assert(takeOverTriggered, 'Takeover not triggered. No changes to the holder.')
    -- If takeover happens, activate all stakes
    for staker, _ in pairs(NameRecords[name].stakers) do
        for _, stake in pairs(Stakes[staker][name]) do
            stake.activationHeight = m["Block-Height"]
        end
    end
 
	NameRecords[name].holder = highestTotalStaker;
	NameRecords[name].lastTakeOverHeight = m['Block-Height'];

    print("New record holder resolved")
end

Handlers.add(
    "resolveNewRecordHolder",
    Handlers.utils.hasMatchingTag("Action", "ResolveNewRecordHolder"),
    function (m)
        local status, err = pcall(resolveNewRecordHolder, m)
        if not status then
            ao.send({
                Target = m.From,
                Tags = { Action = 'ResolveNewRecordHolder-Error', Error = err }
            })
        else
            ao.send({
                Target = m.From,
                Tags = { Action = 'ResolveNewRecordHolder-Response', Response = "New record holder resolved for name " .. m.RecordName }
            })
        end
    end
)
