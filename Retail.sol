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

    address[] private sellers; // the addresses of buyers

    uint private sellerDepositThreshold = 50; // as long as one pay more than this amount of eth can he/she becomes the seller.
    uint private temporaryBalance = 0; // before the transaction is completed/returned, all the eth should be kept in here.
    uint private sellerDeposit = 0;

    mapping(address => Buyer) private buyers;
    mapping(address => uint[]) private buyerTransactions;

    mapping(uint => Product) private products;
    uint private productCount = 0;

    mapping(uint => Transaction) private transactions;
    uint private transactionCount = 0;
    uint private returnRequestTxCount = 0;
    uint private returnTxCount = 0;

    function ethFromWei(uint _wei) private pure returns (uint) {
        // to convert wei to eth
        return _wei / (10 ** 18);
    }

    function isTransactionIDValid(uint _txid) private view returns (bool) {
        // to check whether the tx id is valid
        return _txid >= 0 && _txid < transactionCount;
    }

    function isProductIDValid(uint _pid) private view returns (bool) {
        // to check whether the product id is valid
        return _pid >= 0 && _pid < productCount;
    }

    function isTransactionBelongToBuyer(
        address _sender,
        uint _id
    ) private view returns (bool) {
        // to check whether the tx id belongs to someone
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
        // to check whether there is already a registered seller
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

    function isPurchaseIDsValid(
        Purchase[] memory _purchases
    ) private view returns (bool) {
        // to check whether product ids in purchases are valid
        for (uint i = 0; i < _purchases.length; i++) {
            if (!isProductIDValid(_purchases[i].productID)) return false;
        }
        return true;
    }

    function isPurchasesHaveDupID(
        Purchase[] memory _purchases
    ) private pure returns (bool) {
        // to check whether there are duplicated product ids in one tx (which I think is not allowed)
        for (uint i = 0; i < _purchases.length - 1; i++) {
            for (uint j = i + 1; j < _purchases.length; j++) {
                if (_purchases[j].productID == _purchases[i].productID)
                    return true;
            }
        }
        return false;
    }

    function isInventoryEnough(
        Purchase[] memory _purchases
    ) private view returns (bool) {
        // to check whether the inventory is enough
        mapping(uint => Product) storage productInInventory = products;
        for (uint i = 0; i < _purchases.length; i++) {
            uint productID = _purchases[i].productID;
            uint quantity = _purchases[i].quantity;
            if (quantity > productInInventory[productID].inventory)
                return false;
        }
        return true;
    }

    function isETHEnough(
        Purchase[] memory _purchases,
        uint _wei
    ) private view returns (bool) {
        // to check whether the buyer pays enough eth for this tx
        uint eth = ethFromWei(_wei);
        uint sumCost = 0;
        for (uint i = 0; i < _purchases.length; i++) {
            uint productID = _purchases[i].productID;
            uint quantity = _purchases[i].quantity;
            uint price = products[productID].price;
            uint cost = quantity * price;
            sumCost += cost;
        }
        return eth == sumCost;
    }

    modifier initiateTransactionCriteria(
        uint _wei,
        Purchase[] memory _purchases
    ) {
        require(isPurchaseIDsValid(_purchases), "Invalid product id!");
        require(!isPurchasesHaveDupID(_purchases), "There are duplicated ids!");
        require(
            isInventoryEnough(_purchases),
            "There are not enough inventories!"
        );
        require(
            isETHEnough(_purchases, msg.value),
            "You should pay correct eth!"
        );
        _;
    }

    function initiateTransaction(
        Purchase[] memory _purchases
    ) public payable initiateTransactionCriteria(msg.value, _purchases) {
        mapping(uint => Product) storage storageProducts = products;
        uint newTransactionID = transactionCount;
        transactionCount++;
        Transaction storage t = transactions[newTransactionID];
        t.id = newTransactionID;
        uint transactionAmount = 0;
        for (uint i = 0; i < _purchases.length; i++) {
            Purchase memory newPurchase;
            t.purchases.push(newPurchase);
            Purchase storage p = t.purchases[t.purchases.length - 1];
            p.productID = _purchases[i].productID;
            p.quantity = _purchases[i].quantity;
            storageProducts[_purchases[i].productID].inventory -= _purchases[i]
                .quantity; //deduct inventory
            transactionAmount +=
                storageProducts[_purchases[i].productID].price *
                p.quantity;
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

        Purchase[] storage returnedPurchases = transactions[_id].purchases;
        for (uint i = 0; i < returnedPurchases.length; i++) {
            Purchase storage p = returnedPurchases[i];
            products[p.productID].inventory += p.quantity; // give back the inventory.
        }

        address payable buyer = payable(returnNeededTx.buyer);
        uint returnETHAmount = returnNeededTx.amount;
        bool sent = buyer.send(returnETHAmount * 10 ** 18);
        require(sent, "Failed to send Ether");
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
        bool sent = seller.send(ETHAmount * 10 ** 18);
        require(sent, "Failed to send Ether");
        temporaryBalance -= ETHAmount;
    }
}
