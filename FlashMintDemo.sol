pragma solidity 0.5.16;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.3.0/contracts/ownership/Ownable.sol";
import "./IERC20.sol";

/*
* This contract flash-mints unbacked fWETH and uses it to interact with dummyDEX, Kyber and Uniswap
*/
contract FlashMintDemo is Ownable {

    // Initialize flash mint interfaces
    IExchange public exchange = IExchange(0x0D8F5aB7A0f5aA16a9bAAc38205f3E39855486eB); // address of flash mint compatible DEX
    IFlashWETH public fWETH = IFlashWETH(exchange.fWETH()); // address of FlashWETH contract
    
    // Initialize Kyber proxy trading parameters on ropsten
    IERC20 internal constant ETH_TOKEN_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 internal constant daiToken = IERC20(0xaD6D458402F60fD3Bd25163575031ACDce07538D);
    IKyberNetworkProxy kyberProxy = IKyberNetworkProxy(address(0xd719c34261e099Fdb33030ac8909d5788D3039C4));

    // Initialize parameters for uniswap on ropsten
    uint256 erc20UniTrade;
    UniswapFactoryInterface uniswapFactory = UniswapFactoryInterface(0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351);
    UniswapExchangeInterface uniswapExchange = UniswapExchangeInterface(uniswapFactory.getExchange(0xaD6D458402F60fD3Bd25163575031ACDce07538D));

    // Initialize generic trading parameters
    address payable public platformWallet;
    uint256 public platformFeeBps = 9;
    uint maxDestAmount = 250000000000000000000000000;
    uint256 srcQty;
    
    /*
    * flash mint entry point function
    */
    function beginFlashMint(uint256 _mintAmount, address payable _flashMintContract, uint256 _srcQtyKyber, uint256 _erc20UniTrade) public payable onlyOwner {
        
        platformWallet = _flashMintContract;
        srcQty = _srcQtyKyber;
        erc20UniTrade = _erc20UniTrade;
        
        fWETH.flashMint(_mintAmount); // potential attack vector? --> fWETH.flashMint(exchange.ethBalance());
        
    }

    /*
    * mid flash mint execution (i.e. what you do with the temporarily acquired flash liquidity)
    */
    function executeOnFlashMint(uint256 _amount) external payable {
        
        // Note: At this point you now hold '_amount' number of Flash WETH on this contract
        
        // ensure the caller of this function is the IFlashWETH instance
        require(msg.sender == address(fWETH), "only FlashWETH can execute");
        
        // grant the exchange fWETH spending approval
        fWETH.approve(address(exchange), _amount);
        
        // deposit the unbacked flash minted fWETH onto the exchange to receive equal 'credits'
        exchange.depositFWETH(_amount);

        // redeem the 'credits' from the deposited FWETH to withdraw the same amount of ETH
        exchange.withdrawETH(_amount);

        // Note: At this point you now hold actual ETH so you can arbitrage, collateral swap, self liquidation...etc on other DEXs and protocols
        
        // ETH to DAI swap on Kyber
        uint256 DAIBought = executeSwapOnKyber(ETH_TOKEN_ADDRESS, srcQty, daiToken, platformWallet, maxDestAmount);

        // DAI to ETH swap on uniswap
        erc20ToETHOnUniswap(erc20UniTrade); // trade 'erc20UniTrade' amount of DAI back into ETH

        // once you're done with whatever profitable thing you did, use the ETH balance to flash mint enough fWETH to resolve the original flash mint
        fWETH.deposit.value(_amount)();
        
        // whatever ETH is left over by this point is your profit
    }

    /*
    * Swap from srcToken to destToken (including ether) on Kyber
    */
    function executeSwapOnKyber(
        IERC20 srcToken,
        uint256 _srcQty,
        IERC20 destToken,
        address payable destAddress,
        uint256 _maxDestAmount
    ) public payable returns (uint256) {
        if (srcToken != ETH_TOKEN_ADDRESS) {
            // set the spender's token allowance to tokenQty
            require(srcToken.approve(address(kyberProxy), _srcQty), "approval to _srcQty failed");
        }

        // Get the minimum conversion rate
        uint256 minConversionRate = kyberProxy.getExpectedRateAfterFee(
            srcToken,
            destToken,
            _srcQty,
            platformFeeBps,
            '' // empty hint
        );

        // Execute the trade and send to destAddress
        uint256 tokensBought = kyberProxy.tradeWithHintAndFee.value(_srcQty)(
            srcToken,
            _srcQty,
            destToken,
            destAddress,
            _maxDestAmount,
            minConversionRate,
            platformWallet,
            platformFeeBps,
            '' // empty hint
        );
        
        return tokensBought;
    }
    
    /*
    * Swap DAI to ETH on Uniswap
    */
    function erc20ToETHOnUniswap(uint256 _ERC20Amount) public {
        
        daiToken.approve(address(uniswapExchange), _ERC20Amount);
        
        // calculates how much ether you'll get for _ERC20Amount of DAI
        uint256 ethAmount = uniswapExchange.getTokenToEthInputPrice(_ERC20Amount);
        
        // transfers the equivalent amount of the ERC20 token to the caller of this contract
        uniswapExchange.tokenToEthTransferInput(
           _ERC20Amount,
           ethAmount,
           now + 300,
           platformWallet
        );
    }    
    
    // fallback method
    function () external payable {}
    
    // helper methods
    function withdrawMyDAI() public onlyOwner { daiToken.transfer(msg.sender, daiToken.balanceOf(address(this))); }
    function withdrawMyETH() public onlyOwner { msg.sender.transfer(address(this).balance); }
    function withdrawMyFWETH() public onlyOwner { fWETH.transfer(msg.sender, fWETH.balanceOf(address(this))); }
    function ethBalance() external view returns (uint256) { return address(this).balance; }
    function fwethBalance() external view returns (uint256) { return fWETH.balanceOf(address(this)); }
}

interface IExchange {
    function depositETH() external;
    function depositFWETH(uint256) external;
    function withdrawETH(uint256) external;
    function withdrawFWETH(uint256) external;
    function internalSwapToETH(uint256) external;
    function internalSwapToFWETH(uint256) external;
    function ethBalance() external returns (uint256);
    function fwethBalance() external returns (uint256);
    function fWETH() external returns (address);
}

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

interface IKyberNetworkProxy {

    event ExecuteTrade(
        address indexed trader,
        IERC20 src,
        IERC20 dest,
        address destAddress,
        uint256 actualSrcAmount,
        uint256 actualDestAmount,
        address platformWallet,
        uint256 platformFeeBps
    );

    /// @notice backward compatible
    function tradeWithHint(
        ERC20 src,
        uint256 srcAmount,
        ERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable walletId,
        bytes calldata hint
    ) external payable returns (uint256);

    function tradeWithHintAndFee(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external payable returns (uint256 destAmount);

    function trade(
        IERC20 src,
        uint256 srcAmount,
        IERC20 dest,
        address payable destAddress,
        uint256 maxDestAmount,
        uint256 minConversionRate,
        address payable platformWallet
    ) external payable returns (uint256);

    /// @notice backward compatible
    /// @notice Rate units (10 ** 18) => destQty (twei) / srcQty (twei) * 10 ** 18
    function getExpectedRate(
        ERC20 src,
        ERC20 dest,
        uint256 srcQty
    ) external view returns (uint256 expectedRate, uint256 worstRate);

    function getExpectedRateAfterFee(
        IERC20 src,
        IERC20 dest,
        uint256 srcQty,
        uint256 platformFeeBps,
        bytes calldata hint
    ) external view returns (uint256 expectedRate);
}

// to support backward compatible contract name -- so function signature remains same
contract ERC20 is IERC20 {

}

// Factory interface imported from https://docs.uniswap.io/smart-contract-integration/interface
contract UniswapFactoryInterface {
    // Public Variables
    address public exchangeTemplate;
    uint256 public tokenCount;
    // Create Exchange
    function createExchange(address token) external returns (address exchange);
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
    function getToken(address exchange) external view returns (address token);
    function getTokenWithId(uint256 tokenId) external view returns (address token);
    // Never use
    function initializeFactory(address template) external;
}

// Exchange interface imported from https://docs.uniswap.io/smart-contract-integration/interface
contract UniswapExchangeInterface {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view returns (address factory);
    // Provide Liquidity
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable returns (uint256);
    function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) external returns (uint256, uint256);
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
    // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable returns (uint256  tokens_bought);
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable returns (uint256  tokens_bought);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable returns (uint256  eth_sold);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256  eth_bought);
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address recipient) external returns (uint256  eth_bought);
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external returns (uint256  tokens_sold);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address token_addr) external returns (uint256  tokens_sold);
    function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external returns (uint256  tokens_sold);
    // Trade ERC20 to Custom Pool
    function tokenToExchangeSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_bought);
    function tokenToExchangeSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address exchange_addr) external returns (uint256  tokens_sold);
    function tokenToExchangeTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address exchange_addr) external returns (uint256  tokens_sold);
    // ERC20 comaptibility for liquidity tokens
    bytes32 public name;
    bytes32 public symbol;
    uint256 public decimals;
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 value) external returns (bool);
    function approve(address _spender, uint256 _value) external returns (bool);
    function allowance(address _owner, address _spender) external view returns (uint256);
    function balanceOf(address _owner) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    // Never use
    function setup(address token_addr) external;
}