const Test = require('./config/testConfig.js');
const BigNumber = require('bignumber.js');

const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");

let config;
let app;
let appData;
let acc;
let insuranceAmount;

const TIMESTAMP = Math.floor(Date.now() / 1000);
const FLIGHT = 'FJ';
const STATUS_DELAYED_AIRLINE = 20;

contract('Flight Surety FlightSurety', async (accounts) => {
    acc = accounts;
    config = await Test.Config(accounts);
});

before('setup contract', async () => {
    appData = await FlightSuretyData.new();
    app = await FlightSuretyApp.new(appData.address);
    insuranceAmount = web3.utils.toWei("1", "ether");
    await appData.authorizeContract(app.address, {from: config.owner});
});

/****************************************************************************************/
/* Operations and Settings                                                              */
/****************************************************************************************/

it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await appData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
});

it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try 
    {
        await appData.setOperatingStatus(false, { from: config.testAddresses[2] });
    }
    catch(e) {
        accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
        
});

it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try 
    {
        await appData.setOperatingStatus(false);
    }
    catch(e) {
        accessDenied = true;
    }
    assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
    
});

it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

    await appData.setOperatingStatus(false);

    let reverted = false;
    try 
    {
        await app.setTestingMode(true);
    }
    catch(e) {
        reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

    // Set it back for other tests to work
    await appData.setOperatingStatus(true);

});

it('Owner should be able to register a app contract for authorization', async () => {

    let eventEmitted = false;

    await appData.contract.events.ContractAuthorized((err, res) => {
        eventEmitted = true
    });

    await appData.authorizeContract(app.address, {from: config.owner});

    assert.equal(eventEmitted, true, "Contract was not authorized.");
});

it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

// ARRANGE
let newAirline = acc[2];

// Ideally you should pass `{from: app.address}` but truffle does not recoginize the sender address
// as it is not part of the accounts it provides
// Ref : https://ethereum.stackexchange.com/questions/56593/error-sender-account-not-recognized-when-calling-transferfrom-on-an-erc721
await appData.registerAirline(newAirline, FLIGHT, {from: config.owner});

let result = await appData.isAirline.call(newAirline); 

// ASSERT
assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

});


it('Customer should be able to buy insurance', async () => {

    let eventEmitted = false;

    await appData.contract.events.InsurancePurchased((err, res) => {
        eventEmitted = true
    });

    await appData.buy(config.firstAirline, FLIGHT, TIMESTAMP, {from: config.owner, value: insuranceAmount});

    let contractBalance = await appData.getBalance.call();

    assert.equal(contractBalance, insuranceAmount, "Amount collected does not match.");
    assert.equal(eventEmitted, true, "InsurancePurchased was not emmited.");
});


it('Customer should be able to withdraw insurance payout', async () => {

    let customer1 = acc[3];
    let customer2 = acc[4];
    let customer3 = acc[5];
    let customer4 = acc[6];
    let customerBalanceAfterBuy;

    // buy multiple insurance
    await appData.buy(config.firstAirline, FLIGHT, TIMESTAMP, {from: customer1, value: insuranceAmount});
    await appData.buy(config.firstAirline, FLIGHT, TIMESTAMP, {from: customer2, value: insuranceAmount});
    await appData.buy(config.firstAirline, FLIGHT, TIMESTAMP, {from: customer3, value: insuranceAmount});
    await appData.buy(config.firstAirline, FLIGHT, TIMESTAMP, {from: customer4, value: insuranceAmount});

    customerBalanceAfterBuy = await web3.eth.getBalance(customer2); 

    // credit insurance on assumed flight delay
    let eventFlightStatusUpdatedEmitted = false;

    await appData.contract.events.FlightStatusUpdated((err, res) => {
        eventFlightStatusUpdatedEmitted = true
    });

    await appData.processFlightStatus(config.firstAirline, FLIGHT, TIMESTAMP, STATUS_DELAYED_AIRLINE, {from: config.owner});

    // Withdraw the insurance payout by customer
    let eventAccountWithdrawnEmitted = false;

    await appData.contract.events.AccountWithdrawn((err, res) => {
        eventAccountWithdrawnEmitted = true
    });

    await appData.pay(customer2, {from: customer2});

    let currentCustomerBalance = await web3.eth.getBalance(customer2);

    assert.equal(eventFlightStatusUpdatedEmitted, true, "InsureeCredited was not emitted.");
    assert.equal(eventAccountWithdrawnEmitted, true, "AccountWithdrawn was not emitted.");
    assert.equal(currentCustomerBalance > customerBalanceAfterBuy, true, "Balance is not greater than after purchase." )
});