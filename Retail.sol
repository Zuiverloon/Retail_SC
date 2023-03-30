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

    //address[] public buyers; // the addresses of buyers

    address[] public sellers; // the addresses of buyers
    //todo: public for debuging, need to be private
    uint public sellerDepositThreshold = 10; // as long as one pay more than 10 eth can it becomes the seller.
    uint public sellerDeposit = 0; // the amount of eth the seller deposit

    mapping(address => string) public buyerName; // the name of each buyer
    //todo: public for debuging, need to be private

    mapping(address => string) public buyerEmail; // the email of each buyer
    //todo: public for debuging, need to be private

    mapping(address => string) public buyerAddr; // the shipping address of each buyer
    //todo: public for debuging, need to be private
    mapping(address => Buyer) public buyers;

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
    ) public {
        address buyer = msg.sender;
        require(!isBuyerRegistered(buyer), "The buyer has registered !"); // if the buyer has registered, throw error!
        require(!isSellerRegistered(buyer), "You are registered as a seller !"); // sellers are not allowed to be buyers!
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
    ) public {
        address buyer = msg.sender;
        require(isBuyerRegistered(buyer), "The buyer has not registered yet"); // if the buyer has not registered, throw error!
        buyers[buyer].name = _name;
        buyers[buyer].email = _email;
        buyers[buyer].shipAddr = _shipAddr;
    }

    function sellerRegister(uint _deposit) external payable {
        address seller = msg.sender;
        require(!isBuyerRegistered(seller), "You are already a buyer!"); // a buyer cannot become a seller
        require(!isSellerRegistered(seller), "You are already a seller!"); // a seller cannot register twice.
        require(sellers.length < 1, "Only one seller are allowed!"); // only one address can be the seller.
        uint deposit = _deposit;
        require(deposit >= sellerDepositThreshold, "You should deposit more !"); // the seller should deposit a certain amount of money
        sellerDeposit = deposit;
        sellers.push(seller);
    }
}
