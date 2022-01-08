// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

contract USDCVault is Ownable {
    
    address public deployedTokenContractAddress;
    bool reEntrancyMutex = false;

    mapping (address => uint256) public balances;

    event Transfer(uint256 amount);
    event CurrentContractBalance(uint256 contractBalance);

    constructor(address _deployedTokenContractAddress) {
        deployedTokenContractAddress = _deployedTokenContractAddress;
    }

    modifier onlyContract {
        if (msg.sender != deployedTokenContractAddress) revert();
        _;
    }

    /// @dev Returns the smart contract balance in USDC 
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUSDCBalance() public view returns (uint256) {
        return IERC20("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48").balanceOf(address(this));
    }
    
    /// @dev Function that the token contract calls to deposit USDC into the vault
    /// @param tokenHolder The address of the token holder that sells
    /// @param amount The amount of USDC to deposit
    function deposit(address tokenHolder, uint256 amount) public onlyContract {
        require(msg.sender == deployedTokenContractAddress, "Only the deployed token contract can deposit funds");
        balances[tokenHolder] += amount;

        /// @notice how do we transfer from the user to the contract?
        payable(address(this)).transfer(amount);
        emit CurrentContractBalance(balances[tokenHolder]);
    }

    /// @dev Calculate the user rewards using the formula in the whitepaper
    /// @param amount Amount of tokens they want to withdraw
    function calculateUserRewards(uint256 amount) internal view returns (uint256) {
        uint256 totalContractTokenSupply = address(this).balance;
        
        /// @notice This is a filler- the oracle logic will be used in here to calculate the actual dollar rewards ($price of token * totalContractTokenSupply) / overall user ownership 
        uint256 totalRewards = totalContractTokenSupply / amount;
       
        return totalRewards;
    }

    /// @notice We want to allow the owner to withdraw everything if he chooses to do so- this does open up a lot of security vulnerabilities
    /// @param amount Amount of token that the user wants to withdraw
    /// @notice need reentrancy guard to prevent someone from calling this function multiple times 
    function withdrawUserRewards(uint256 amount) payable external {
        uint256 contractBalance = address(this).balance;
        require(amount <= contractBalance);

        // transfer from contract balance to user
        uint256 userRewards = calculateUserRewards(amount);
        payable(msg.sender).transfer(userRewards);
        contractBalance -= amount;
        
        emit Transfer(amount);
        emit CurrentContractBalance(contractBalance);
    }
}
