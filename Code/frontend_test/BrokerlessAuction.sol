pragma solidity >=0.4.22 <0.7.0;

contract BrokerlessAuction {
    
    address payable public landlord;
    
    address payable public leaseAddress;
    
    address payable public omnibusAddress;

    // Current state of the auction.
    address public tenant;
    uint public highestBid;
    uint public rentPercent;
    uint public depositPercent;
    uint public rent;
    uint public deposit;
    
//    uint public showingFeePercent
//    string public apt;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    // Events that will be emitted on changes.
    event rentIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    // The following is a so-called natspec comment,
    // recognizable by the three slashes.
    // It will be shown when the user is asked to
    // confirm a transaction.

    enum State {Started, Terminated}
    State public state;

    /*constructor*/
/*
    constructor(string memory _apt, uint _showingFeePercent) public {
        landlord = msg.sender;
        state = State.Started;
        apt = _apt;
        showingFeePercent = _showingFeePercent;
    }
*/
    /* test constructor*/
    constructor() public {
        landlord = msg.sender;
        state = State.Started;
    }
    
    /* modifiers */
    modifier inState(State _state) {
        require(state == _state, "The auction is not active.");
        _;
    }    
    modifier onlyLandlord() {
        require(landlord == msg.sender, "You must be the landlord to perform this function.");
        _;
    }
    
    /// identifies the BrokerlessContract address (instead can we have this corntact CREATE the BrokerlessContract?)
    function setLeaseAddress(address payable _address) public payable {
        leaseAddress = _address;
    }
    
    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    
    function bid(uint _rentPercent, uint _depositPercent) public payable
    inState(State.Started)
    {
        // If the bid is not higher, send the money back.
        require(landlord != msg.sender);
        require(msg.value > highestBid, "There already is a higher bid.");
        require(_depositPercent <= _rentPercent);

        if (highestBid != 0) {
            // Sending back the money by simply using
            // tenant.send(rent) is a security risk
            // because it could execute an untrusted contract.
            // It is always safer to let the recipients
            // withdraw their money themselves.
            pendingReturns[tenant] += highestBid;
        }
        //tenant = msg.sender;
        tenant = msg.sender;
        highestBid = msg.value;
        rentPercent = _rentPercent;
        depositPercent = _depositPercent;
        emit rentIncreased(msg.sender, msg.value);
    }

    /// Withdraw a bid that was overbid.
    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    function pendingReturn() public view returns (uint) {
        return pendingReturns[msg.sender];
    }
    
    function setOmnibusContract(address payable _address) public payable
    {
    omnibusAddress = _address;
    }
    
    function getbalance() public view returns (uint) {
        return address(this).balance;
    }

    /// End the auction and send the highest bid to the BrokerlessContract.
    function auctionEnd() public
    inState(State.Started)
    onlyLandlord
    {
        // It is a good guideline to structure functions that interact
        // with other contracts (i.e. they call functions or send Ether)
        // into three phases:
        // 1. checking conditions
        // 2. performing actions (potentially changing conditions)
        // 3. interacting with other contracts
        // If these phases are mixed up, the other contract could call
        // back into the current contract and modify the state or cause
        // effects (ether payout) to be performed multiple times.
        // If functions called internally include interaction with external
        // contracts, they also have to be considered interaction with
        // external contracts.

        // 1. Conditions as modifiers

        // 2. Effects
        state = State.Terminated;
        emit AuctionEnded(tenant, highestBid);

        // 3. Interaction
        rent = highestBid * rentPercent/100;
        deposit = highestBid * depositPercent/100;
        leaseAddress.transfer(rent);
        omnibusAddress.transfer(deposit);
    }
}

