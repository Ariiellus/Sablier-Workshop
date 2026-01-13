// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ERC20
 * @notice This ERC20 contract has four write functions: mint, transfer, approve, transferFrom
 * @notice mint function is not part of the ERC20 standard, but is included here for convenience
 */

contract ERC20 {
    string public name;
    string public symbol;

    mapping(address => uint256) public balanceOf; // stores everyone's balances
    address public owner;
    uint8 public decimals;

    uint256 public totalSupply; // needs to be updated every time a new token is minted or burned

    // the address x allows address y spend n amount of tokens
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // The constructor allows to initialize a new token with an specifc name and symbol
    // Should we include a maximum supply?
    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        decimals = 18;

        owner = msg.sender;
    }

    /**
     * @notice This function
     * @dev Find the risk of the current implementation
     */
    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "only owner can create tokens");
        require(amount > 0, "amount must be greater than 0");
        require(to != address(0), "cannot mint to address(0)");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) public {
        require(msg.sender != address(0), "cannot burn from zero address");
        require(balanceOf[msg.sender] >= amount, "you do not have enough tokens");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "you do not have enough tokens");
        require(to != address(0), "cannot send to address(0)");

        balanceOf[msg.sender] -= amount; // balance needs to be debited first
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount; // the caller allows an spender certain amount
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice This function is usually used by contracts to transfer tokens on behalf of users
     * @param from The address that owns the tokens and has given allowance to msg.sender
     * @param to The address receiving the tokens (can be any address, not just a contract)
     * @param amount The amount of tokens to transfer
     * @notice Subtracting the spending amount from allowance prevents unlimited spending
     */
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "you do not have enough tokens");
        require(to != address(0), "cannot send to address(0)");

        if (msg.sender != from) {
            require(allowance[from][msg.sender] >= amount, "not enough allowance");
            allowance[from][msg.sender] -= amount;
        }

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);

        return true;
    }
}
