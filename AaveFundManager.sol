pragma solidity 0.5.12;

import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPool.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/ILendingPoolAddressesProvider.sol";
import "https://github.com/mrdavey/ez-flashloan/blob/remix/contracts/aave/FlashLoanReceiverBase.sol";

contract AaveFundManager is Ownable {
    
    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(address(0x1c8756FD2B28e9426CDBDcC7E3c4d64fa9A54728)); // ropsten address, for other addresses: https://docs.aave.com/developers/developing-on-aave/deployed-contract-instances
    ILendingPool lendingPool = ILendingPool(provider.getLendingPool());
    address lendingPoolCore = address(provider.getLendingPoolCore());
    
    // Input variables
    address daiAddress = address(0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108); // ropsten DAI
    address aDaiAddress = address(0xcB1Fe6F440c49E9290c3eb7f158534c2dC374201); //ropsten aDAI
    IERC20 dai = IERC20(daiAddress);
    IERC20 aDAI = IERC20(aDaiAddress);
    
    /*
    * deposits _depositAmount of _reserveAsset onto the lending pool   
    */
    function deposit(address _reserveAsset, uint256 _depositAmount) public onlyOwner {
        
        if (_reserveAsset == daiAddress) {
            // Approve LendingPool contract to move your DAI if user is depositing DAI
            dai.approve(lendingPoolCore, _depositAmount);
        }
        
        // Deposit _depositAmount of _reserveAsset
        lendingPool.deposit(_reserveAsset, _depositAmount, uint16(0));
    }
    
    /*
    * borrows _borrowAmount of _reserveAsset from the lending pool, assuming you have deposited enough collateral
    */
    function borrow(address _reserveAsset, uint256 _borrowAmount) public onlyOwner {
        
        if (_reserveAsset == daiAddress) {
            // Approve LendingPool contract to move your DAI if user is depositing DAI
            dai.approve(lendingPoolCore, _borrowAmount);
        }
        
        // 1 is stable rate, 2 is variable rate
        lendingPool.borrow(_reserveAsset, _borrowAmount, 2, uint16(0));
        
    }
    
    /*
    * repays _repayAmount of _reserveAsset to the lending pool
    */
    function repay(address _reserveAsset, uint256 _repayAmount) public onlyOwner {
        
        if (_reserveAsset == daiAddress) {
            // Approve LendingPool contract to move your DAI if user is depositing DAI
            dai.approve(lendingPoolCore, _repayAmount);
        }
        
        // Repay own loan
        lendingPool.repay(_reserveAsset, _repayAmount, msg.sender);
    }
    
    /*
    * repays _repayAmount of _reserveAsset to the lending pool on behalf of _onBehalfOfAddress 
    */
    function repayOnBehalf(address _reserveAsset, uint256 _repayAmount, address _onBehalfOfAddress) public onlyOwner {
        
        if (_reserveAsset == daiAddress) {
            // Approve LendingPool contract to move your DAI if user is depositing DAI
            dai.approve(lendingPoolCore, _repayAmount);
        }
        
        // repays loan on behalf of _onBehalfOfAddress
        lendingPool.repay(_reserveAsset, _repayAmount, _onBehalfOfAddress);
    }

    /*
    * Liquidate positions with a health factor below 1
    */
    function liquidator(address _collateralAddress, address _liquidateeAddress, uint256 _purchaseAmount) public onlyOwner {
    
        // Approve LendingPool contract to move your DAI
        dai.approve(lendingPoolCore, _purchaseAmount);

        /// LiquidationCall method call
        lendingPool.liquidationCall(
            _collateralAddress,
            daiAddress,
            _liquidateeAddress,
            _purchaseAmount,
            true
        );
    }

    /*
    * withdraw all ETH and DAI on contract back to you
    */
    function clearContractFunds() public onlyOwner {
        
        // withdraw DAI
        dai.transfer(msg.sender, dai.balanceOf(address(this)));
        
        // withdraw ETH
        msg.sender.transfer(address(this).balance);
        
        // withdraw aDAI
        aDAI.transfer(msg.sender, aDAI.balanceOf(address(this)));

    }
    
    // to enable lending pool to send borrowed funds to this contract
    function () external payable {}

}
