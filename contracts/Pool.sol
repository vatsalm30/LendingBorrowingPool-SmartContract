// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// Uniswap Contract Address: 0x0227628f3F023bb0B980b67D528571c95c6DaC1c
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import "./Interface/IPool.sol";

// Interest Calculation Equations:
// Borrowed Rate = 0.02 + 0.03 * Utilization + 0.2 * Utilization ** 10
// Deposit Rate = Borrowed Rate * Utilization

contract Pool is IPool, ReentrancyGuard {
    uint256 private constant DECIMALS = 18;

    // Only Testnet, Change After Deploying on Mainet
    address private constant USD = 0xbdfBcCcfd102ee458725a3f510e03A106ba7A738;
    address private constant UNISWAPFACTORY = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;

    mapping(address => mapping(address => uint256)) depositBalances;
    mapping(address => address[]) depositedAddress;

    mapping(address => mapping(address => uint256)) borrowedBalances;
    mapping(address => address[]) borrowedAddress;


    mapping(address => uint256) netDeposits;
    mapping(address => uint256) netBorrows;

    // User Must Allow Before Depositing
    function deposit(address _asset, uint256 _amount) external nonReentrant
    {
        uint amount = _amount * 10**ERC20(_asset).decimals();
        require(amount <= IERC20(_asset).balanceOf(msg.sender), "Pool: Not Enough Balance");
        require(amount <= IERC20(_asset).allowance(msg.sender, address(this)), "Pool: Transfer Not Autherized");
        IERC20(_asset).transferFrom(msg.sender, address(this), amount);
        depositBalances[msg.sender][_asset] += amount;
        netDeposits[_asset] += amount;
        depositedAddress[msg.sender].push(_asset);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Deposit(msg.sender, _asset, amount, depositRate, borrowRate, block.timestamp);
    }
    function withdraw(address _asset, uint256 _amount) external nonReentrant
    {
        uint amount = _amount * 10**ERC20(_asset).decimals();
        uint256 userNetLiquidAssets = getAssetsSum(depositedAddress[msg.sender], depositBalances[msg.sender]);
        uint256 userNetBorrowedAssets = getAssetsSum(borrowedAddress[msg.sender], borrowedBalances[msg.sender]);

        require(amount <= depositBalances[msg.sender][_asset], "Pool: Not Enough Balance");
        require(userNetLiquidAssets - amount * calculatePrice(_asset)/(10**18) > userNetBorrowedAssets, "Pool: Can't Withdraw, Too Much Borrowed");
        IERC20(_asset).transfer(msg.sender, amount);
        depositBalances[msg.sender][_asset] -= amount;
        netDeposits[_asset] -= amount;

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Withdraw(msg.sender, _asset, _amount, depositRate, borrowRate, block.timestamp);
    }
    function borrow(address _asset, uint256 _amount) external nonReentrant
    {
        uint amount = _amount * 10**ERC20(_asset).decimals();
        uint256 userNetLiquidAssets = getAssetsSum(depositedAddress[msg.sender], depositBalances[msg.sender]);
        uint256 userNetBorrowedAssets = getAssetsSum(borrowedAddress[msg.sender], borrowedBalances[msg.sender]);

        uint256 liquidAssets = userNetLiquidAssets;
        // Check if user has enough assets and calculate risk; if risk above 80% then don't allow to borrow
        require(amount * calculatePrice(_asset)/(10**18) + userNetBorrowedAssets <= liquidAssets, "Pool: Not Enough Collateral Assets");
        borrowedBalances[msg.sender][_asset] += amount;
        netBorrows[_asset] += amount;
        borrowedAddress[msg.sender].push(_asset);

        IERC20(_asset).transfer(msg.sender, amount);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Borrow(msg.sender, _asset, amount, depositRate, borrowRate, block.timestamp);
    }

    // User Must Allow Before Repaying
    function repay(address _asset, uint256 _amount) external nonReentrant
    {
        uint amount = _amount * 10**ERC20(_asset).decimals();
        require(amount <= borrowedBalances[msg.sender][_asset], "Pool: No Need To Repay This Amount");
        require(amount <= IERC20(_asset).allowance(msg.sender, address(this)), "Pool: Transfer Not Autherized");
        require(amount <= IERC20(_asset).balanceOf(msg.sender), "Pool: Not Enough Balance");
        borrowedBalances[msg.sender][_asset] -= amount;
        netBorrows[_asset] -= amount;

        IERC20(_asset).transferFrom(msg.sender, address(this), amount);

        (uint256 borrowRate, uint256 depositRate) = reCalculateRates(_asset);

        emit Repay(msg.sender, _asset, amount, depositRate, borrowRate, block.timestamp);
    }
    function liquidate(address _user, address _collateralAsset, address _borrowedAsset) external nonReentrant
    {
        // This implementation is extremly flawed because it doesn't properly check the users balance.

        (uint256 borrowRate,) = reCalculateRates(_borrowedAsset);
        (, uint256 depositRate) = reCalculateRates(_collateralAsset);

        emit Liquidate(_user, _collateralAsset, IERC20(_collateralAsset).balanceOf(_user), depositRate, borrowRate, block.timestamp);
    }

    function reCalculateRates(address _asset) private view returns (uint256, uint256)
    {
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

    function calculatePrice(address _asset) private view returns (uint256) 
    {
        if(_asset == USD)
        {
            return 10**18;
        }

        address poolAddress = getAddress(_asset);

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
        
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        
        uint256 sqrtPriceX96Pow = uint256(sqrtPriceX96 * 10**12);

        uint256 priceFromSqrtX96 = sqrtPriceX96Pow / 2**96;
        
        priceFromSqrtX96 = priceFromSqrtX96**2; 

        uint256 priceAdj = priceFromSqrtX96 * 10**6; 

        uint256 finalPrice = ((1 * 10**48) / priceAdj);

        return 10**36/finalPrice;
    }

    function getAddress(address _asset) private view returns (address) 
    {
        IUniswapV3Factory factory = IUniswapV3Factory(UNISWAPFACTORY);
        return factory.getPool(USD, _asset, 500);
    }

    function getAssetsSum(address[] memory addresses, mapping(address => uint256) storage amountOfEach) private view returns (uint256)
    {
        uint256 sum = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            address addressKey = addresses[i];
            uint256 value = amountOfEach[addressKey];

            sum += (value * calculatePrice(addressKey))/(10**18);
        }

        return sum;
    }

    function getUserBalances(address user, address _asset) public view returns (uint256, uint256)
    {
        return (depositBalances[user][_asset], borrowedBalances[user][_asset]);
    }
    function getAssetBalances(address _asset) public view returns (uint256, uint256){
        return (netDeposits[_asset], netBorrows[_asset]);
    }
    function getInterestRates(address _asset) public view returns (uint256, uint256){
        return reCalculateRates(_asset);
    }
}