// SPDX-License-Identifier: MIT
// IEMS 5725 Project: Retail
// Name: Junyao Zhang
// ID:   1155183057
pragma solidity ^0.8.0;

contract Retail {
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
    uint public sellerDepositThreshold = 50; // as long as one pay more than 10 eth can it becomes the seller.
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
    uint public productCount = 0;

    mapping(uint => Transaction) public transactions;
    uint public transactionCount = 0;
    uint public returnRequestTxCount = 0;
    uint public returnTxCount = 0;

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
        // to check whether the sender has registered as a buyer
        return buyers[_addr].addr != address(0);
    }

    function isSellerRegistered(address _addr) private view returns (bool) {
        // to check whether the sender has registered as a seller
        if (sellers.length == 0) return false;
        return _addr == sellers[0];
    }

    modifier buyerRegisterCriteria(address _sender) {
        require(!isBuyerRegistered(_sender), "You have registered!"); // One cannot register as buyer twice.
        require(!isSellerRegistered(_sender), "You are a seller!"); // A seller cannot register as a buyer
        _;
    }

    function buyerRegister(
        string memory _name,
        string memory _email,
        string memory _shipAddr
    ) public buyerRegisterCriteria(msg.sender) {
        address buyer = msg.sender;
        Buyer storage buyerObj = buyers[buyer];
        buyerObj.addr = buyer;
        buyerObj.name = _name;
        buyerObj.email = _email;
        buyerObj.shipAddr = _shipAddr;
    }

    modifier buyerProfileUpdateCriteria(address _sender) {
        require(isBuyerRegistered(_sender), "You are not a buyer!"); // Only registered buyers can update profile
        _;
    }

    function buyerProfileUpdate(
        string memory _name,
        string memory _email,
        string memory _shipAddr
    ) public buyerProfileUpdateCriteria(msg.sender) {
        address buyer = msg.sender;
        buyers[buyer].name = _name;
        buyers[buyer].email = _email;
        buyers[buyer].shipAddr = _shipAddr;
    }

    function hasSeller() private view returns (bool) {
        return sellers.length > 0;
    }

    modifier sellerRegisterCriteria(address _sender, uint _deposit) {
        require(!hasSeller(), "There is a seller registered!"); //Only one seller is allowed.
        require(
            !isBuyerRegistered(_sender),
            "You are already registered as a buyer!"
        ); // A buyer cannot be a seller.
        require(
            _deposit / (10 ** 18) >= sellerDepositThreshold,
            "You should deposit more eth!"
        ); // the seller should deposit enough eth
        _;
    }

    function sellerRegister()
        external
        payable
        sellerRegisterCriteria(msg.sender, msg.value)
    {
        address seller = msg.sender;
        uint deposit = msg.value / (10 ** 18); // convert wei to eth
        sellerDeposit = deposit;
        sellers.push(seller);
    }

    modifier addProductCriteria(address _sender) {
        require(
            isSellerRegistered(_sender),
            "You are not a seller,not allowed to add product"
        ); // Only the seller can add product.
        _;
    }

    function addProduct(
        string memory _name,
        uint _price,
        uint _inventory
    ) public addProductCriteria(msg.sender) {
        uint newProductID = productCount;
        productCount++;
        Product storage newProduct = products[newProductID];
        newProduct.id = newProductID;
        newProduct.name = _name;
        newProduct.price = _price;
        newProduct.inventory = _inventory;
    }

    modifier getProductInfoCriteria(uint _pid) {
        require(isProductIDValid(_pid), "Invalid product ID"); // The product id should be valid;
        _;
    }

    function getProductInfo(
        uint _id
    ) public view getProductInfoCriteria(_id) returns (Product memory) {
        return products[_id];
    }

    modifier initiateTransactionCriteria(
        uint _wei,
        Purchase[] memory _purchases
    ) {
        mapping(uint => Product) storage productInInventory = products;
        uint eth = ethFromWei(_wei);
        uint sumCost = 0;
        for (uint i = 0; i < _purchases.length; i++) {
            uint productID = _purchases[i].productID;
            uint quantity = _purchases[i].quantity;
            require(
                quantity <= productInInventory[productID].inventory,
                "Product not enough in inventory!"
            );
            uint price = products[productID].price;
            uint cost = quantity * price;
            sumCost += cost;
        }
        require(eth == sumCost, "You should pay correct eth!");
        _;
    }

    function initiateTransaction(
        Purchase[] memory purchases
    ) public payable initiateTransactionCriteria(msg.value, purchases) {
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

    modifier getTransactionInfoCriteria(address _sender, uint _tid) {
        if (isSellerRegistered(_sender)) {
            require(isTransactionIDValid(_tid), "Invalid Transaction ID!"); // Seller can see all VALID transactions.
        } else if (isBuyerRegistered(_sender)) {
            require(
                isTransactionBelongToBuyer(_sender, _tid),
                "The TX does not belong to you!"
            ); // One buyer can only see his/her own TX.
        } else {
            require(isBuyerRegistered(_sender), "You are not a buyer!"); // Only registered buyers can see some transactions.
        }
        _;
    }

    function getTransactionInfo(
        uint _id
    )
        public
        view
        getTransactionInfoCriteria(msg.sender, _id)
        returns (Transaction memory)
    {
        return transactions[_id];
    }

    modifier returnRequestModifier(address _sender, uint _txid) {
        require(isBuyerRegistered(_sender), "You are not a buyer!"); //Only buyers can request a return.
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

    function returnRequest(
        uint _id
    ) public returnRequestModifier(msg.sender, _id) {
        transactions[_id].status = TransactionStatus.RETURN_REQUESTED;
        returnRequestTxCount++;
        returnTxCount++;
        if (returnTxCount % 10 == 0) {
            // for every 10 return requests, the seller will receive a penalty. The seller deposit will be deduct by 1 eth, as long as the seller deposit is not zero.
            if (sellerDeposit > 0) sellerDeposit--;
        }
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
        uint returnRequestTxIndex = 0;
        for (uint i = 0; i < transactionCount; i++) {
            if (transactions[i].status == TransactionStatus.RETURN_REQUESTED) {
                returnRequestTx[returnRequestTxIndex] = transactions[i];
                returnRequestTxIndex++;
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
