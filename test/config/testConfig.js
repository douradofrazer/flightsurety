
const BigNumber = require('bignumber.js');

const Config = async function(accounts) {
    
    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0xF314FAD9EF9f94685EfB1fb7650d82Add398Ec27",
        "0x2528458eDCE7b1B478e2d20815BB407Bc1BA4E86",
        "0x346C5D6DF888C574B3a161F1e9810D41e0990570",
        "0xfB4d40B6D9201F15A7f1f90Bf7687c7Fe1c56f91",
        "0x8828b0Ac9bc260E481792FE0F5c0Bab42a8b6886",
        "0xf22be2b7D775F3Cc7355B71A5980646e63403380",
        "0x0c18beBC703aAdE4F10f4cFE6dcF9bC5cADBFD97"
    ];

    let owner = accounts[0];
    let firstAirline = accounts[1];

    return {
        owner: owner,
        firstAirline: firstAirline,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses
    }
}

module.exports = {
    Config: Config
};