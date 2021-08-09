const Pin = artifacts.require("dummy/Pin.sol");
const Zrx = artifacts.require("dummy/Zrx.sol");
const Exc = artifacts.require("Exc.sol");
const Fac = artifacts.require("Factory.sol");
const Pool = artifacts.require("Pool.sol");

contract("Pool", (accounts) => {
    let pin, zrx, exc;
    const [trader1, trader2] = [accounts[1], accounts[2]];
    const [PIN, ZRX] = ["PIN", "ZRX"].map((ticker) => web3.utils.fromAscii(ticker));

    beforeEach(async () => {
        [pin, zrx] = await Promise.all([Pin.new(), Zrx.new()]);
        exc = await Exc.new();
        fac = await Fac.new();
    });

    it("initialize + deposit", async () => {
        let factory = await fac.createPair(
            pin.address,
            zrx.address,
            pin.address,
            exc.address,
            PIN,
            ZRX
        );
        const pool = await Pool.at(factory.logs[0].args.pair);
        const balance = 1000;
        await pin.mint(trader1, balance);
        await pin.approve(pool.address, balance, { from: trader1 });
        await pool.deposit(0, balance, { from: trader1 });
        const poolBalancePIN = await exc.traderBalances.call(pool.address, PIN);
        const poolBalanceZRX = await exc.traderBalances.call(pool.address, ZRX);
        assert.equal(parseInt(poolBalancePIN), balance);
        assert.equal(parseInt(poolBalanceZRX), balance);
    });

    it("withdraw", async () => {
        let factory = await fac.createPair(
            pin.address,
            zrx.address,
            pin.address,
            exc.address,
            PIN,
            ZRX
        );
        const pool = await Pool.at(factory.logs[0].args.pair);
        const balance = 1000;
        await pin.mint(trader1, balance);
        pin.approve(pool.address, balance, { from: trader1 });
        zrx.mint(trader1, balance);
        zrx.approve(pool.address, balance, { from: trader1 });
        await pool.deposit(balance, balance, { from: trader1 });
        const orders1 = await exc.getOrders(ZRX, 0);
        await pool.withdraw(balance, balance, { from: trader1 });
        const orders2 = await exc.getOrders(ZRX, 0);
        assert.equal(orders1[0].ticker, orders2[0].ticker);
        assert.equal(orders1[0].price, orders2[0].price);
    });
});
