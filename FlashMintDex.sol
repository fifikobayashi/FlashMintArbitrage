pragma solidity 0.5.16;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/token/ERC20/SafeERC20.sol";

interface IFlashWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function flashMint(uint256) external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// @notice A constant-sum market for ETH and fWETH
contract FlashMintDex {

    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    address constant public fWETH = 0xD4f239B1be6a0bdCf7e150AB1E43b453e101EF5a; // address of FlashWETH contract

    // users get "credits" for depositing ETH or fWETH
    // credits can be redeemed for an equal number of ETH or fWETH
    // e.g.: You can deposit 5 fWETH to get 5 "credits", and then immediately use those credits to
    // withdrawl 5 ETH.
    mapping (address => uint256) public credits;

   // fallback must be payable and empty to receive ETH from the FlashWETH contract
    function () external payable {}

    // ==========
    //  DEPOSITS
    // ==========

    // Gives depositor credits for ETH
    function depositETH() public payable {
        credits[msg.sender] = credits[msg.sender].add(msg.value);
    }

    // Gives depositor credits for fWETH
    function depositFWETH(uint256 amount) public payable {
        ERC20(fWETH).safeTransferFrom(msg.sender, address(this), amount);
        credits[msg.sender] = credits[msg.sender].add(amount);
    }

    // =============
    //  WITHDRAWALS
    // =============

    // Redeems credits for ETH
    function withdrawETH(uint256 amount) public {
        credits[msg.sender] = credits[msg.sender].sub(amount);
        // if the contract doesn't have enough ETH then try to get some
        uint256 ethBalance = address(this).balance;
        if (amount > ethBalance) {
            internalSwapToETH(amount.sub(ethBalance));
        }
        msg.sender.transfer(amount);
    }

    // Redeems credits for fWETH
    function withdrawFWETH(uint256 amount) public {
        credits[msg.sender] = credits[msg.sender].sub(amount);
        // if the contract doesn't have enough fWETH then try to get some
        uint256 fWethBalance = ERC20(fWETH).balanceOf(address(this));
        if (amount > fWethBalance) {
            internalSwapToFWETH(amount.sub(fWethBalance));
        }
        ERC20(fWETH).safeTransfer(msg.sender, amount);
    }

    // ===================
    //  INTERNAL EXCHANGE (not secure, for demo purposes only)
    // ===================

    // Forces this contract to convert some of its own fWETH to ETH
    function internalSwapToETH(uint256 amount) public {
        // redeem fWETH for ETH via the FlashWETH contract
        IFlashWETH(fWETH).withdraw(amount);
    }

    // Forces this contract to convert some of its own ETH to fWETH
    function internalSwapToFWETH(uint256 amount) public {
        // deposit ETH for fWETH via the FlashWETH contract
        IFlashWETH(fWETH).deposit.value(amount)();
    }

    // =========
    //  GETTERS
    // =========

    function ethBalance() external view returns (uint256) { return address(this).balance; }
    function fwethBalance() external view returns (uint256) { return ERC20(fWETH).balanceOf(address(this)); }

}

// note: sum of all credits should be at most address(this).balance.add(ERC20(fWETH).balanceOf(address(this)));