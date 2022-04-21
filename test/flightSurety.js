
const Test = require('./config/testConfig.js');
const BigNumber = require('bignumber.js');

const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");

let config;
let app;
let appData;
let acc;

contract('Flight Surety FlightSurety', async (accounts) => {
    acc = accounts;
    config = await Test.Config(accounts);
});

before('setup contract', async () => {
    // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    appData = await FlightSuretyData.new();
    app = await FlightSuretyApp.new(appData.address);
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

await appData.authorizeContract(app.address, {from: config.owner});

// Ideally you should pass `{from: app.address}` but truffle does not recoginize the sender address
// as it is not part of the accounts it provides
// Ref : https://ethereum.stackexchange.com/questions/56593/error-sender-account-not-recognized-when-calling-transferfrom-on-an-erc721
await appData.registerAirline(newAirline, 'JZ', {from: config.owner});

let result = await appData.isAirline.call(newAirline); 

// ASSERT
assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

});
