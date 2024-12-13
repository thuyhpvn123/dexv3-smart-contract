pragma solidity 0.7.6;
pragma abicoder v2;
import {Test, console} from "forge-std/Test.sol";
import {PancakeV3PoolDeployer} from "../src/v3-core/contracts/PancakeV3PoolDeployer.sol";
import {PancakeV3Factory} from "../src/v3-core/contracts/PancakeV3Factory.sol";
import {WrappedETH} from "../src/v3-periphery/contracts/wbnb.sol";
import {BEP20} from "../src/v3-periphery/contracts/bep20.sol";
import {NFTDescriptorEx} from "../src/v3-periphery/contracts/NFTDescriptorEx.sol";
import {NonfungibleTokenPositionDescriptor} from "../src/v3-periphery/contracts/NonfungibleTokenPositionDescriptor.sol";
import {NonfungiblePositionManager} from "../src/v3-periphery/contracts/NonfungiblePositionManager.sol";
import {INonfungiblePositionManager as IPOSITION_MANAGER} from"../src/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {GetPoolInitCodeHashSmC} from "../src/v3-core/contracts/GetInitCodeHash.sol";
import '../src/v3-periphery/contracts/libraries/PoolAddress.sol';
import {IPancakeV3Pool} from "../src/v3-core/contracts/interfaces/IPancakeV3Pool.sol";
import {SwapRouter} from "../src/v3-periphery/contracts/SwapRouter.sol";
import {ISwapRouter as IROUTER} from"../src/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {QuoterV2} from "../src/v3-periphery/contracts/lens/QuoterV2.sol";
import {IQuoterV2 as IQUOTER} from "../src/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {TickMath} from "../src/v3-core/contracts/libraries/TickMath.sol";

contract PancakeTest is Test {
    PancakeV3PoolDeployer public POOL_DEPLOYER;
    PancakeV3Factory public FACTORY;
    NFTDescriptorEx public NFT_DES_EX;
    NonfungibleTokenPositionDescriptor public POSITION_DES;
    NonfungiblePositionManager public POSITION_MANAGER;
    BEP20 public TOKEN0;
    BEP20 public TOKEN1;
    WrappedETH public WBNB;
    GetPoolInitCodeHashSmC public GET_CODE_HASH;
    SwapRouter public ROUTER;
    QuoterV2 public QUOTER;
    address public Deployer = address(0x1);
    address public userA = address(0x2);
    address public userB = address(0x3);
    bytes32 public nativeCurrencyLabelBytes = 0x424e420000000000000000000000000000000000000000000000000000000000 ;//WBNB
    uint256 public DECIMAL1 = 10**18;
    uint256 public DECIMAL0 = 10**18;
    constructor(){
        vm.startPrank(Deployer);
        WBNB = new WrappedETH();
        POOL_DEPLOYER = new PancakeV3PoolDeployer();
        FACTORY = new PancakeV3Factory(address(POOL_DEPLOYER));
        NFT_DES_EX = new NFTDescriptorEx();       
        POSITION_DES = new NonfungibleTokenPositionDescriptor(address(WBNB),nativeCurrencyLabelBytes,address(NFT_DES_EX));
        POSITION_MANAGER = new NonfungiblePositionManager(address(POOL_DEPLOYER),address(FACTORY),address(WBNB),address(POSITION_DES));
        TOKEN1 = new BEP20("DAI","DAI");
        TOKEN0 = new BEP20("BTC","BTC");
        GET_CODE_HASH = new GetPoolInitCodeHashSmC();
        bytes32 codeHashActual = GET_CODE_HASH.GetPoolInitCodeHash();
        bytes32 codeHashInContract = PoolAddress.POOL_INIT_CODE_HASH;
        assertEq(codeHashActual,codeHashInContract,"should equal");
        TOKEN0.mint(userA,1_000 * DECIMAL0);
        TOKEN1.mint(userA,1_000 * DECIMAL1);
        TOKEN0.mint(userB,1_000 * DECIMAL0);
        TOKEN1.mint(userB,1_000 * DECIMAL1);
        POOL_DEPLOYER.setFactoryAddress(address(FACTORY));
        console.log("TOKEN0:",address(TOKEN0));
        console.log("TOKEN1:",address(TOKEN1));
        //
        ROUTER = new SwapRouter(address(POOL_DEPLOYER),address(FACTORY),address(WBNB));
        QUOTER = new QuoterV2(address(POOL_DEPLOYER),address(FACTORY),address(WBNB));
        vm.stopPrank();
    }
    function testMint()public{
        addPoolTokens();
        // addPoolTokenETH();
        GetByteCode();
    }
    function addPoolTokens()public{
        vm.startPrank(userA);
        TOKEN0.approve(address(POSITION_MANAGER),1_000 * DECIMAL0);
        TOKEN1.approve(address(POSITION_MANAGER),1_000 * DECIMAL1);

        // address pool = FACTORY.createPool(address(TOKEN0),address(TOKEN1),500);
        uint256 token1Price = 5000 * DECIMAL1;
        uint256 token0Price = 1 * DECIMAL0;       
        // uint160 sqrtPriceX96 = uint160(sqrt(token1Price/token0Price) * 2**96); //bat buoc sqrtPriceX96= token1/token0 
        // console.log("sqrtPriceX96:",uint256(sqrtPriceX96));
        uint160 sqrtPriceX96 = 1120455419495722800000000000000; //neu tinh bang cong thuc se ra sai lech
        /*chu y :
        - khi goi createAndInitializePoolIfNecessary:can sap xep token0,token1 theo thu tu abc truoc neu ko se revert kho bao ly do
        - neu tickLower va tickUpper nam ngoai current price range thi amount0Min hoac amount1Min se = 0
            -> revert Price slippage check -> neu muon add liquidity ngoai khoang gia hien tai thi de amount0Min =0 hoac amount1Min = 0
            4295128739 <= sqrtPriceX96 < 1461446703485210103287273052203988822378723970342 ->revert "R"
        */
        //tao pool
        address pool1 = POSITION_MANAGER.createAndInitializePoolIfNecessary(address(TOKEN0),address(TOKEN1),500,sqrtPriceX96);

        //mint lan 1 so luong token0 va token 1 tuy y thi liquidity se la min(liquidity0 va liquidity1)-> ra amount tuong ung
        IPOSITION_MANAGER.MintParams memory mintParam1 = IPOSITION_MANAGER.MintParams({
            token0: address(TOKEN0), 
            token1: address(TOKEN1),//doi vi tri 2 token thi cung thay doi tick vi thay doi ty gia
            fee: 500, //0.05% -> tickspace = 60
            tickLower: 48930, //-> gia 4981,938 
            tickUpper: 59920, //->gia 5042,07
            amount0Desired: 6000, 
            amount1Desired: 979748,
            amount0Min: 0,
            amount1Min: 0,
            recipient: userA,
            deadline: 1000000000000
        });
        POSITION_MANAGER.mint(mintParam1);
        IQUOTER.QuoteExactInputSingleParams memory paramsQuoter = IQUOTER.QuoteExactInputSingleParams({
            tokenIn: address(TOKEN1),
            tokenOut: address(TOKEN0),
            amountIn: 2000,
            fee: 500,
            // sqrtPriceLimitX96: uint160(_getSqrtPriceLimitX96(address(TOKEN0),address(TOKEN1)))
            sqrtPriceLimitX96: 0

        });
        (uint256 amountOutExpect1,uint160 sqrtPriceX96After,uint32 initializedTicksCrossed,uint256 gasEstimate) = QUOTER.quoteExactInputSingle(paramsQuoter);
        // console.log("amountOutExpect1:",amountOutExpect1);
        // console.log("sqrtPriceX96After:",uint256(sqrtPriceX96After));

        // address pool1Expect =FACTORY.getPool(address(TOKEN0),address(TOKEN1),500);
        // assertEq(pool1,pool1Expect,"should be equal");
        // assertEq(TOKEN0.balanceOf(pool1),46261,"should be equal");
        // assertEq(TOKEN1.balanceOf(pool1),100000000,"should be equal");
        // uint128 liquidity = IPancakeV3Pool(pool1).liquidity();
        // assertEq(uint256(liquidity),782286256,"should be equal");

        // //mint lan 2 - truong hop nhap muon add token0 = 100000000-> amount1 do pool tu tinh
        // IPOSITION_MANAGER.MintParams memory mintParam2 = IPOSITION_MANAGER.MintParams({
        //     token0: address(TOKEN0), 
        //     token1: address(TOKEN1),//doi vi tri 2 token thi cung thay doi tick vi thay doi ty gia
        //     fee: 500, //0.05% -> tickspace = 60
        //     tickLower: 85140, //-> gia 4981,938 
        //     tickUpper: 85260, //->gia 5042,07
        //     amount0Desired: 100000000,
        //     amount1Desired: 216165826119,
        //     amount0Min: 1,
        //     amount1Min: 1,
        //     recipient: userA,
        //     deadline: 1000000000000
        // });
        // POSITION_MANAGER.mint(mintParam2);
        // assertEq(TOKEN0.balanceOf(pool1),46261+100000000,"should be equal");
        // assertEq(TOKEN1.balanceOf(pool1),100000000+216165826119,"should be equal");
        // assertEq(POSITION_MANAGER.totalSupply(),2,"should be equal");
        // address owner = POSITION_MANAGER.ownerOf(2);
        // assertEq(POSITION_MANAGER.balanceOf(userA),2,"should be equal");
        // assertEq(POSITION_MANAGER.tokenByIndex(1),2,"should be equal");
        // liquidity = IPancakeV3Pool(pool1).liquidity();
        // assertEq(uint256(liquidity),1691817835217,"should be equal"); //1691817835217= 782286256 lan 1 + 1691035548961 lan2
        
        // //decrease liquidity 20%
        // uint256 bal0Before = 1_000 * DECIMAL0 - 46261 - 100000000;
        // assertEq(TOKEN0.balanceOf(userA),bal0Before,"should be equal");
        // (,,,,,,,uint128 liquidity1,,,,) = POSITION_MANAGER.positions(1);
        // assertEq(uint256(liquidity1),782286256,"should be equal"); 
        // uint128 decreaseAmountTokenId1 = liquidity1*20/100;
        // IPOSITION_MANAGER.DecreaseLiquidityParams memory decreaseParam1 = IPOSITION_MANAGER.DecreaseLiquidityParams({
        //     tokenId: 1,
        //     liquidity: decreaseAmountTokenId1,
        //     amount0Min: 1,
        //     amount1Min: 1,
        //     deadline: 1000000000000
        // });
        // (uint256 amount0Decrease, uint256 amount1Decrease) = POSITION_MANAGER.decreaseLiquidity(decreaseParam1);
        // liquidity = IPancakeV3Pool(pool1).liquidity();
        // uint256 liquiAfterDecrease = 1691817835217-decreaseAmountTokenId1;
        // assertEq(uint256(liquidity),liquiAfterDecrease,"should be equal"); 
        // assertEq(TOKEN0.balanceOf(userA),bal0Before,"should be equal");

        // //sau khi decrease can goi ham collect de tra 2 token release ve cho userA
        // IPOSITION_MANAGER.CollectParams memory collectParam =  IPOSITION_MANAGER.CollectParams({
        //     tokenId: 1,
        //     recipient: userA,
        //     amount0Max: uint128(amount0Decrease),
        //     amount1Max: uint128(amount1Decrease)
        // });
        // POSITION_MANAGER.collect(collectParam);
        // assertEq(TOKEN0.balanceOf(userA),bal0Before + amount0Decrease,"should be equal");

        // //increase liquidity
        // IPOSITION_MANAGER.IncreaseLiquidityParams memory increaseParam1 = IPOSITION_MANAGER.IncreaseLiquidityParams({
        //     tokenId: 1,
        //     amount0Desired: 100000000,
        //     amount1Desired: 216165826119,
        //     amount0Min: 0,
        //     amount1Min: 0,
        //     deadline: 1000000000000
        // });
        // POSITION_MANAGER.increaseLiquidity(increaseParam1);
        // liquidity = IPancakeV3Pool(pool1).liquidity();
        // assertEq(uint256(liquidity),liquiAfterDecrease +1691035548961,"should be equal");
        vm.stopPrank();
        // swapIn(pool1);
        // swapOut(pool1);
    }
    function swapIn(address pool)public{
        vm.startPrank(userB);
        TOKEN0.approve(address(ROUTER),1_000 * DECIMAL0);
        TOKEN1.approve(address(ROUTER),1_000 * DECIMAL1);

        //exactInput: swap qua nhieu cap token o nhieu muc phi khac nhau
        // address pool =FACTORY.getPool(address(TOKEN0),address(TOKEN1),500);
        uint256 balToken0Before = TOKEN0.balanceOf(pool);

        address[] memory tokens = new address[](2);
        tokens[0] = address(TOKEN0);
        tokens[1] = address(TOKEN1);
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;
        bytes memory path = _encodePath(tokens,fees);
        IROUTER.ExactInputParams memory paramExactInput = IROUTER.ExactInputParams({
            path : path,
            recipient : userB,
            deadline : 1000000000000,
            amountIn : 10000,
            amountOutMinimum : 1 
        });
        uint256 amountOut = ROUTER.exactInput(paramExactInput); //=49974989
        console.log("amountOut:",amountOut);
        assertEq(TOKEN1.balanceOf(userB),1_000 * DECIMAL1 + amountOut,"should be equal");
        assertEq(TOKEN0.balanceOf(userB),1_000 * DECIMAL0 - 10000,"should be equal");
        (uint256 amountOutExpect,,,) = QUOTER.quoteExactInput(path,10000);
        assertLt(amountOut-amountOutExpect,100,"difference is too big"); // 2 ket qua ko bang nhau nhung sai lech it
        uint256 balToken0After = TOKEN0.balanceOf(pool);
        assertEq(balToken0After ,balToken0Before + 10000,"should be equal");

        //exactInputSingle: swap cap 2 token 
        IROUTER.ExactInputSingleParams memory paramExactInputSingle = IROUTER.ExactInputSingleParams({
            tokenIn: address(TOKEN0),
            tokenOut: address(TOKEN1),
            fee: 500,
            recipient: userB,
            deadline: 1000000000000,
            amountIn: 10000,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: uint160(_getSqrtPriceLimitX96(address(TOKEN0),address(TOKEN1)))
        });
        uint256 amountOut1 = ROUTER.exactInputSingle(paramExactInputSingle);
        console.log("amountOut1:",amountOut1);
        assertEq(TOKEN1.balanceOf(userB),1_000 * DECIMAL1 + amountOut + amountOut1,"should be equal");
        assertEq(TOKEN0.balanceOf(userB),1_000 * DECIMAL0 - 10000 - 10000,"should be equal");
        IQUOTER.QuoteExactInputSingleParams memory paramsQuoter = IQUOTER.QuoteExactInputSingleParams({
            tokenIn: address(TOKEN0),
            tokenOut: address(TOKEN1),
            amountIn: 10000,
            fee: 500,
            sqrtPriceLimitX96: uint160(_getSqrtPriceLimitX96(address(TOKEN0),address(TOKEN1)))
        });
        (uint256 amountOutExpect1,,,) = QUOTER.quoteExactInputSingle(paramsQuoter);
        assertLt(amountOut1-amountOutExpect1,100,"difference is too big"); //49974989 - 49974968 ->2 ket qua ko bang nhau nhung sai lech it
        uint256 balToken0After1 = TOKEN0.balanceOf(pool);
        assertEq(balToken0After1 ,balToken0After + 10000,"should be equal");
        vm.stopPrank();
    }
    function swapOut(address pool)public{
        vm.startPrank(userB);
        //exactOutputSingle
        uint256 bal0Before = TOKEN0.balanceOf(userB);
        uint256 bal1Before = TOKEN1.balanceOf(userB);
        uint256 bal0PoolBefore = TOKEN0.balanceOf(pool);
        IROUTER.ExactOutputSingleParams memory paramExactOutputSingle = IROUTER.ExactOutputSingleParams({
            tokenIn: address(TOKEN0),
            tokenOut: address(TOKEN1),
            fee: 500,
            recipient: userB,
            deadline: 1000000000000,
            amountOut: 49974989,
            amountInMaximum: 1000000000000,
            sqrtPriceLimitX96: uint160(_getSqrtPriceLimitX96(address(TOKEN0),address(TOKEN1)))
        });
        uint256 amountIn = ROUTER.exactOutputSingle(paramExactOutputSingle);
        console.log("amountIn:",amountIn);
        assertEq(TOKEN1.balanceOf(userB),bal1Before + 49974989,"should be equal");
        assertEq(TOKEN0.balanceOf(userB),bal0Before - amountIn,"should be equal");
        IQUOTER.QuoteExactOutputSingleParams memory paramQuoteExactOutputSingle = IQUOTER.QuoteExactOutputSingleParams({
            tokenIn: address(TOKEN0),
            tokenOut: address(TOKEN1),
            amount: 49974989,
            fee: 500,
            sqrtPriceLimitX96: uint160(_getSqrtPriceLimitX96(address(TOKEN0),address(TOKEN1)))
        });
        (uint256 amountInExpect,,,) = QUOTER.quoteExactOutputSingle(paramQuoteExactOutputSingle);
        assertEq(amountIn,amountInExpect,"difference is too big"); //49974989 - 49974968 ->2 ket qua ko bang nhau nhung sai lech it
        console.log("amountInExpect:",amountInExpect);
        uint256 bal0PoolAfter = TOKEN0.balanceOf(pool);
        assertEq(bal0PoolAfter ,bal0PoolBefore + amountIn,"should be equal");

        //exactOutput
        address[] memory tokens = new address[](2);
        tokens[0] = address(TOKEN1); // tokenOut
        tokens[1] = address(TOKEN0); //tokenIn
        uint24[] memory fees = new uint24[](1);
        fees[0] = 500;
        bytes memory path = _encodePath(tokens,fees);
        IROUTER.ExactOutputParams memory paramExactOutput = IROUTER.ExactOutputParams({
        path : path,
        recipient : userB,
        deadline : 1000000000000,
        amountOut : 49974989,
        amountInMaximum : 1000000000000
        });
        uint256 amountIn1 = ROUTER.exactOutput(paramExactOutput);
        console.log("amountIn1:",amountIn1);
        (uint256 amountInExpect1,,,) = QUOTER.quoteExactOutput(path,49974989);
        console.log("amountInExpect1:",amountInExpect1);

        vm.stopPrank();
    }
    function addPoolTokenETH()public{

    }
    function _getSqrtPriceLimitX96(address tokenIn, address tokenOut) internal pure returns (uint256) {
        return tokenIn < tokenOut
            ? TickMath.MIN_SQRT_RATIO +1
            : TickMath.MAX_SQRT_RATIO -1;
    }
    function _encodePath(address[] memory path, uint24[] memory fees) internal pure returns (bytes memory) {
        require(path.length == fees.length + 1, "path/fee lengths do not match");

        bytes memory encoded;
        for (uint256 i = 0; i < fees.length; i++) {
            // 20-byte encoding of the address (address size is 20 bytes)
            encoded = abi.encodePacked(encoded, path[i]);
            // 3-byte encoding of the fee (uint24 fits in 3 bytes)
            encoded = abi.encodePacked(encoded, fees[i]);
        }
        // Encode the final token address
        encoded = abi.encodePacked(encoded, path[path.length - 1]);

        return encoded;
    }
    function GetByteCode()public{
        address token0 = 0x337D74B01d76c91d1a1Fe4Caa2542EE876aa37BD;
        address token1 = 0xb1a4BC8abd4e9d1dF81E04115941AAc3B118cF8E;
        address user = 0xB50b908fFd42d2eDb12b325e75330c1AaAf35dc0;
        uint160 sqrtPriceX96 =5602277097478610000000000000000;

        bytes memory bytesCodeCall = abi.encodeWithSignature(
            "createAndInitializePoolIfNecessary(address,address,uint24,uint160)",
            token0,
            token1,
            500,
            sqrtPriceX96
        );
        console.log("createAndInitializePoolIfNecessary:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  
        IPOSITION_MANAGER.MintParams memory mintParam = IPOSITION_MANAGER.MintParams({
            token0: token0, 
            token1: token1,
            fee: 500, 
            tickLower: 85140,
            tickUpper: 85260, 
            amount0Desired: 100000000, 
            amount1Desired: 100000000,
            amount0Min: 1,
            amount1Min: 1,
            recipient: user,
            deadline: 1000000000000
        }) ;
        bytesCodeCall = abi.encodeWithSignature(
            "mint",mintParam);
        console.log("mint:");
        console.logBytes(bytesCodeCall);
        console.log(
            "-----------------------------------------------------------------------------"
        );  

    }
}