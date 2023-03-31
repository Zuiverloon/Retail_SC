// SPDX-License-Identifier: MIT
// IEMS 5725 Project: Retail
// Name: Junyao Zhang
// ID:   1155183057
pragma solidity ^0.8.0;

contract Retail {
    modifier transactionIDValid(uint _txid) {
        require(isTransactionIDValid(_txid), "Invalid transaction ID");
        _;
    }
    modifier productIDValid(uint _pid) {
        require(isProductIDValid(_pid), "Invalid product ID");
        _;
    }
    modifier canViewTransaction(uint _id, address _sender) {
        require(
            _sender == sellers[0] || isTransactionBelongToBuyer(_sender, _id),
            "You are not allowed to check this tx"
        );
        _;
    }
    modifier TransactionBelongToBuyer(uint _id, address _sender) {
        require(
            isTransactionBelongToBuyer(_sender, _id),
            "The tx is not yours!"
        );
        _;
    }
    modifier returnRequestEnabled(uint _txid, address _sender) {
        require(isTransactionIDValid(_txid), "Invalid transaction ID");
        require(
            isTransactionBelongToBuyer(_sender, _txid),
            "The transaction does not belong to you!"
        );
        require(
            transactions[_txid].status == TransactionStatus.PURCHASED,
            "You cannot return this."
        );
        _;
    }
    modifier isBuyerPayEnoughEth(uint _eth, Purchase[] memory _purchases) {
        uint sumCost = 0;
        for (uint i = 0; i < _purchases.length; i++) {
            uint productID = _purchases[i].productID;
            uint quantity = _purchases[i].quantity;
            uint price = products[productID].price;
            uint cost = quantity * price;
            sumCost += cost;
        }
        require(_eth == sumCost, "You should pay correct eth!");
        _;
    }
    modifier isRegisteredAsBuyer(address _sender) {
        require(isBuyerRegistered(_sender), "The buyer has not registered yet"); // if the buyer has not registered, throw error!
        _;
    }
    modifier isNotRegisteredAsBuyer(address _sender) {
        require(!isBuyerRegistered(_sender), "The buyer has registered !"); // if the buyer has registered, throw error!
        _;
    }
    modifier isNotRegisteredAsSeller(address _sender) {
        require(
            !isSellerRegistered(_sender),
            "You are registered as a seller !"
        ); // sellers are not allowed to be buyers!
        _;
    }
    modifier hasNoSeller() {
        require(sellers.length == 0, "Only one seller are allowed!"); // only one address can be the seller.
        _;
    }
    modifier isDepositEnough(uint _deposit) {
        uint eth = _deposit / (10 ** 18);
        require(eth >= sellerDepositThreshold, "You should deposit more eth!"); // the seller should deposit more eth
        _;
    }

    struct Buyer {
        address addr;
        string name;
        string email;
        string shipAddr;
    }

    struct Product {
        uint id;
        string name;
        uint price;
        uint inventory;
    }

    enum TransactionStatus {
        PURCHASED,
        RETURN_REQUESTED,
        COMPLETED,
        RETURNED
    }

    struct Transaction {
        uint id;
        Purchase[] purchases; // it supports multi transactions.
        uint amount;
        TransactionStatus status;
        address buyer;
    }

    struct Purchase {
        uint productID;
        uint quantity;
    }

    //address[] public buyers; // the addresses of buyers

    address[] public sellers; // the addresses of buyers

    //todo: public for debuging, need to be private
    uint public sellerDepositThreshold = 10; // as long as one pay more than 10 eth can it becomes the seller.
    uint public temporaryBalance = 0; // before the transaction is completed, all the eth should be kept in here.
    uint public sellerDeposit = 0; // the balance of the seller (including deposit)
    // Transaction[] transactions;

    mapping(address => string) public buyerName; // the name of each buyer
    //todo: public for debuging, need to be private

    mapping(address => string) public buyerEmail; // the email of each buyer
    //todo: public for debuging, need to be private

    mapping(address => string) public buyerAddr; // the shipping address of each buyer
    //todo: public for debuging, need to be private
    mapping(address => Buyer) public buyers;
    mapping(address => uint[]) public buyerTransactions;

    mapping(uint => Product) public products;
    uint productCount = 0;

    mapping(uint => Transaction) public transactions;
    uint transactionCount = 0;
    uint returnRequestTxCount = 0;

    function ethFromWei(uint _wei) public pure returns (uint) {
        return _wei / (10 ** 18);
    }

    function isTransactionIDValid(uint _txid) private view returns (bool) {
        return _txid >= 0 && _txid < transactionCount;
    }

    function isProductIDValid(uint _pid) private view returns (bool) {
        return _pid >= 0 && _pid < productCount;
    }

    function isTransactionBelongToBuyer(
        address _sender,
        uint _id
    ) public view returns (bool) {
        uint[] memory txids = buyerTransactions[_sender];
        for (uint i = 0; i < txids.length; i++) {
            if (txids[i] == _id) return true;
        }
        return false;
    }

    function isBuyerRegistered(address _addr) private view returns (bool) {
        // to check whether a buyer has registered
        return buyers[_addr].addr != address(0);
    }

    function isSellerRegistered(address _addr) private view returns (bool) {
        // to check whether a seller has registered
        for (uint i = 0; i < sellers.length; i++) {
            if (sellers[i] == _addr) return true;
        }
        return false;
    }

    function buyerRegister(
        string memory _name,
        string memory _email,
        string memory _shipAddr
    )
        public
        isNotRegisteredAsBuyer(msg.sender)
        isNotRegisteredAsSeller(msg.sender)
    {
        address buyer = msg.sender;
        Buyer storage buyerObj = buyers[buyer];
        buyerObj.addr = buyer;
        buyerObj.name = _name;
        buyerObj.email = _email;
        buyerObj.shipAddr = _shipAddr;
    }

    function buyerProfileUpdate(
        string memory _name,
        string memory _email,
        string memory _shipAddr
    ) public isRegisteredAsBuyer(msg.sender) {
        address buyer = msg.sender;
        buyers[buyer].name = _name;
        buyers[buyer].email = _email;
        buyers[buyer].shipAddr = _shipAddr;
    }

    function sellerRegister()
        external
        payable
        hasNoSeller
        isNotRegisteredAsBuyer(msg.sender)
        isNotRegisteredAsSeller(msg.sender)
        isDepositEnough(msg.value)
    {
        address seller = msg.sender;
        uint deposit = msg.value / (10 ** 18); // convert wei to eth
        sellerDeposit = deposit;
        sellers.push(seller);
    }

    function addProduct(
        Product memory _product
    ) public isRegisteredAsBuyer(msg.sender) {
        uint newProductID = productCount;
        productCount++;
        Product storage newProduct = products[newProductID];
        newProduct.id = newProductID;
        newProduct.name = _product.name;
        newProduct.price = _product.price;
        newProduct.inventory = _product.inventory;
    }

    function getProductInfo(
        uint _id
    ) public view productIDValid(_id) returns (Product memory) {
        return products[_id];
    }

    function initiateTransaction(
        Purchase[] memory purchases
    ) public payable isBuyerPayEnoughEth(ethFromWei(msg.value), purchases) {
        uint newTransactionID = transactionCount;
        transactionCount++;
        Transaction storage t = transactions[newTransactionID];
        t.id = newTransactionID;
        uint transactionAmount = 0;
        for (uint i = 0; i < purchases.length; i++) {
            Purchase memory newPurchase;
            t.purchases.push(newPurchase);
            Purchase storage p = t.purchases[t.purchases.length - 1];
            p.productID = purchases[i].productID;
            p.quantity = purchases[i].quantity;
            transactionAmount += p.productID * p.quantity;
        }
        t.status = TransactionStatus.PURCHASED;
        t.amount = transactionAmount;
        t.buyer = msg.sender;
        temporaryBalance += transactionAmount;
        buyerTransactions[msg.sender].push(newTransactionID);
    }

    function getTransactionInfo(
        uint _id
    )
        public
        view
        transactionIDValid(_id)
        canViewTransaction(_id, msg.sender)
        returns (Transaction memory)
    {
        return transactions[_id];
    }

    function returnRequest(
        uint _id
    ) public returnRequestEnabled(_id, msg.sender) {
        transactions[_id].status = TransactionStatus.RETURN_REQUESTED;
        returnRequestTxCount++;
    }

    modifier getAllReturnRequestCriteria(address _sender) {
        require(_sender == sellers[0], "You are not seller!");
        _;
    }

    function getAllReturnRequest()
        public
        view
        getAllReturnRequestCriteria(msg.sender)
        returns (Transaction[] memory)
    {
        Transaction[] memory returnRequestTx = new Transaction[](
            returnRequestTxCount
        );
        for (uint i = 0; i < transactionCount; i++) {
            if (transactions[i].status == TransactionStatus.RETURN_REQUESTED) {
                returnRequestTx[i] = transactions[i];
            }
        }
        return returnRequestTx;
    }

    modifier approveReturnRequestCriteria(uint _id, address _sender) {
        require(_sender == sellers[0], "You are not seller!");
        require(isTransactionIDValid(_id), "Invalid Transaction ID!");
        require(transactions[_id].status == TransactionStatus.RETURN_REQUESTED);
        _;
    }

    function approveReturnRequest(
        uint _id
    ) public payable approveReturnRequestCriteria(_id, msg.sender) {
        Transaction storage returnNeededTx = transactions[_id];
        returnNeededTx.status = TransactionStatus.RETURNED;
        returnRequestTxCount--;

        address payable buyer = payable(returnNeededTx.buyer);
        uint returnETHAmount = returnNeededTx.amount;
        buyer.transfer(returnETHAmount);
        temporaryBalance -= returnETHAmount;
    }

    modifier completeTransactionCriteria(uint _id, address _sender) {
        require(isTransactionIDValid(_id), "Invalid Transaction ID!");
        require(
            isTransactionBelongToBuyer(_sender, _id),
            "The TX does not belong to you."
        );
        require(
            transactions[_id].status == TransactionStatus.PURCHASED,
            "The TX cannot be completed!"
        );
        _;
    }

    function completeTransaction(uint _id) public {
        uint ETHAmount = transactions[_id].amount;
        transactions[_id].status = TransactionStatus.COMPLETED;

        address payable seller = payable(sellers[0]);
        seller.transfer(ETHAmount);
    }
}
