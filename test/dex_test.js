const { expectRevert } = require("@openzeppelin/test-helpers");
const Pin = artifacts.require("dummy/Pin.sol");
const Zrx = artifacts.require("dummy/Zrx.sol");
const Exc = artifacts.require("Exc.sol");

const SIDE = {
    BUY: 0,
    SELL: 1,
};

contract("Exc", (accounts) => {
    let pin, zrx, exc;
    const [trader1, trader2] = [accounts[1], accounts[2]];
    const [PIN, ZRX] = ["PIN", "ZRX"].map((ticker) => web3.utils.fromAscii(ticker));

    beforeEach(async () => {
        [pin, zrx] = await Promise.all([Pin.new(), Zrx.new()]);
        exc = await Exc.new();
    });

    it("getOrders", async () => {
        const balance = 1000;
        await exc.addToken(PIN, pin.address);
        await exc.addToken(ZRX, zrx.address);
        await pin.mint(trader1, balance);
        await pin.approve(exc.address, balance, { from: trader1 });
        await exc.deposit(balance, PIN, { from: trader1 });
        const amount = 10;
        const price = 5;
        await exc.makeLimitOrder(ZRX, amount, price, 0, { from: trader1 });
        const order = await exc.getOrders(ZRX, 0);
        assert.equal(order[0].price, price);
        assert.equal(order[0].amount, amount);
        assert.equal(order.length, 1);
    });

    it("addToken", async () => {
        let tokens0 = await exc.getTokens();
        assert.equal(tokens0.length, 0); // check empty list
        await exc.addToken(PIN, pin.address);
        let tokens1 = await exc.getTokens();
        assert.equal(tokens1.length, 1);
        await exc.addToken(ZRX, zrx.address);
        let tokens2 = await exc.getTokens();
        assert.equal(tokens2.length, 2);
    });

    it("deposit", async () => {
        const balance = 1000;
        await exc.addToken(PIN, pin.address);
        await pin.mint(trader1, balance);
        await pin.approve(exc.address, balance, { from: trader1 });
        await exc.deposit(1000, PIN, { from: trader1 });
        const trader1Balance = await exc.traderBalances.call(trader1, PIN);
        assert.equal(parseInt(trader1Balance), balance);
    });

    it("withdraw", async () => {
        const balance = 1000;
        await exc.addToken(PIN, pin.address);
        await pin.mint(trader1, balance);
        await pin.approve(exc.address, balance, { from: trader1 });
        await pin.deposit(500, PIN, { from: trader1 });
        await pin.withdraw(500, PIN, { from: trader1 });
        const trader1Balance = await exc.traderBalances.call(trader1, PIN);
        assert.equal(parseInt(trader1Balance), 0);
    });

    it("makeLimitOrder", async () => {
        await exc.addToken(PIN, pin.address);
        await exc.addToken(ZRX, zrx.address);
        await pin.mint(trader2, 100);
        await pin.approve(exc.address, 50, { from: trader2 });
        await exc.deposit(50, PIN, { from: trader1 });
        await exc.makeLimitOrder(ZRX, 10, 5, 0, { from: trader2 });
        const amount = 10;
        const price = 5;
        await exc.makeLimitOrder(ZRX, amount, price, 0, { from: trader2 });
        const orders = await exc.getOrders(ZRX, 0);
        assert.equal(orders[0].price, price);
        assert.equal(orders[0].amount, amount);
        assert.equal(orders.length, 1);
    });

    it("deleteLimitOrder", async () => {
        const balance = 50;
        await exc.addToken(PIN, pin.address);
        await exc.addToken(ZRX, zrx.address);
        await pin.mint(trader1, balance);
        await pin.approve(exc.address, balance, { from: trader1 });
        await exc.deposit(balance, PIN, { from: trader1 });
        await exc.makeLimitOrder(ZRX, 10, 5, 0, { from: trader1 });
        const amount = 10;
        const price = 5;
        await exc.makeLimitOrder(ZRX, amount, price, 0, { from: trader1 });
        await exc.deleteLimitOrder(0, ZRX, 0, { from: trader1 });
        const orders = await exc.getOrders(ZRX, 0);
        assert.equal(orders.length, 1);
    });

    it("makeMarketOrder", async () => {
        const balance = 1000;
        await exc.addToken(PIN, pin.address);
        await exc.addToken(ZRX, zrx.address);
        await pin.mint(trader1, balance);
        await pin.approve(exc.address, balance, { from: trader1 });
        await exc.deposit(balance, PIN, { from: trader1 });
        await exc.makeLimitOrder(ZRX, 1, 50, 0, { from: trader1 });
        await exc.makeLimitOrder(ZRX, 2, 25, 0, { from: trader1 });
        await zrx.mint(trader2, balance);
        await zrx.approve(exc.address, balance, { from: trader2 });
        await exc.deposit(balance, ZRX, { from: trader2 });
        await exc.makeMarketOrder(ZRX, 2, 10, { from: trader2 });
        const trader1PINBalance = await exc.traderBalances.call(trader1, PIN);
        assert.equal(trader1PINBalance, 100);
        const trader2ZRXBalance = await exc.traderBalances.call(trader2, ZRX);
        assert.equal(trader2ZRXBalance, 980);
    });
});
