// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Uniswap Contract Address: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import "./Interface/IPool.sol";

// Interest Calculation Equations:
// Borrowed Rate = 0.02 + 0.03 * Utilization + 0.2 * Utilization ** 10
// Deposit Rate = Borrowed Rate * Utilization

contract Pool is IPool, ReentrancyGuard {
    uint256 public constant DECIMALS = 18;
    address public constant WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address public constant UNISWAPFACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    mapping(address => mapping(address => uint256)) depositBalances;
    mapping(address => uint256) userNetLiquidAssets;

    mapping(address => mapping(address => uint256)) borrowedBalances;
    mapping(address => uint256) userNetBorrowedAssets;


    mapping(address => uint256) netDeposits;
    mapping(address => uint256) netBorrows;
    // User Must Allow Before Depositing
    function deposit(address _asset, uint256 _amount) external nonReentrant
    {
        require(_amount <= IERC20(_asset).balanceOf(msg.sender), "Pool: Not Enough Balance");
        require(_amount <= IERC20(_asset).allowance(msg.sender, address(this)), "Pool: Transfer Not Autherized");
        IERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        depositBalances[msg.sender][_asset] += _amount;
        netDeposits[_asset] += _amount;

        userNetLiquidAssets[msg.sender] += _amount * calculatePrice(_asset);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Deposit(msg.sender, _asset, _amount, depositRate, borrowRate, block.timestamp);
    }
    function withdraw(address _asset, uint256 _amount) external nonReentrant
    {
        require(_amount <= depositBalances[msg.sender][_asset], "Pool: Not Enough Balance");
        IERC20(_asset).transfer(msg.sender, _amount);
        depositBalances[msg.sender][_asset] -= _amount;
        netDeposits[_asset] -= _amount;

        userNetLiquidAssets[msg.sender] -= _amount * calculatePrice(_asset);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Withdraw(msg.sender, _asset, _amount, depositRate, borrowRate, block.timestamp);
    }
    function borrow(address _asset, uint256 _amount) external nonReentrant
    {
        uint256 liquidAssets = userNetLiquidAssets[msg.sender];
        // Check if user has enough assets and calculate risk; if risk above 80% then don't allow to borrow
        require(_amount * calculatePrice(_asset) + userNetBorrowedAssets[msg.sender] <= liquidAssets, "Pool: Not Enough Collateral Assets");
        borrowedBalances[msg.sender][_asset] += _amount;
        netBorrows[_asset] += _amount;

        userNetBorrowedAssets[msg.sender] += _amount * calculatePrice(_asset);

        IERC20(_asset).transfer(msg.sender, _amount);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Borrow(msg.sender, _asset, _amount, depositRate, borrowRate, block.timestamp);
    }

    // User Must Allow Before Repaying
    function repay(address _asset, uint256 _amount) external nonReentrant
    {
        borrowedBalances[msg.sender][_asset] -= _amount;
        netBorrows[_asset] -= _amount;

        userNetBorrowedAssets[msg.sender] -= _amount * calculatePrice(_asset);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Repay(msg.sender, _asset, _amount, depositRate, borrowRate, block.timestamp);
    }
    function liquidate(address _user, address _collateralAsset, address _borrowedAsset) external nonReentrant
    {
        // This implementation is extremly flawed because it doesn't properly check the users balance.

        (uint256 borrowRate,) = reCalculateRates(_borrowedAsset);
        (, uint256 depositRate) = reCalculateRates(_collateralAsset);

        emit Liquidate(_user, _collateralAsset, IERC20(_collateralAsset).balanceOf(_user), depositRate, borrowRate, block.timestamp);
    }

    function reCalculateRates(address _asset) private view returns (uint256, uint256){
        uint256 borrowRate = 0;
        uint256 depositRate = 0;

        if (netDeposits[_asset] > 0)
        {
            uint256 utilization = (netBorrows[_asset] * 10 ** DECIMALS) / (netDeposits[_asset] * 10 ** DECIMALS);
            borrowRate = (2 * 10 ** DECIMALS)/100 + (3 * utilization)/100 + (2 * utilization ** 10)/10;
            depositRate = borrowRate * utilization;
        }

        return (borrowRate, depositRate);
    }

    function calculatePrice(address _asset) private view returns (uint256) {
        //WETH Address: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 MAINET
        // WETH Address: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9  SEPOLIA

        address poolAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            UNISWAPFACTORY,
                            keccak256(abi.encode(WETH, _asset, 500)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        
        uint256 sqrtPriceX96Pow = uint256(sqrtPriceX96 * 10**12);

        uint256 priceFromSqrtX96 = sqrtPriceX96Pow / 2**96;
        
        priceFromSqrtX96 = priceFromSqrtX96**2; 

        uint256 priceAdj = priceFromSqrtX96 * 10**6; 

        uint256 finalPrice = ((1 * 10**48) / priceAdj) * 10 ** 18;

        return finalPrice;
    }
}