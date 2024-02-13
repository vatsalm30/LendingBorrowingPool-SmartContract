const TestToken = artifacts.require("TestToken");

module.exports = deployer => {
    deployer.deploy(TestToken, "Token 1", "TK1", 100000000);
}