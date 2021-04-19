const Migrations = artifacts.require("Migrations");
const LockUpPool = artifacts.require("LockUpPool");
const ERC20Token = artifacts.require("ERC20Token");

const { toBN } = require("../test/helpers/NumberHelpers");

const isLive = true;

const tokenToDeployList = [
  {
    token: "BTCB",
    addressTest: "0x6ce8dA28E2f864420840cF74474eFf5fD80E65B8",
    addressLive: "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c",
    interestRate: 3.29,
    minimumDeposit: toBN(1, 16),
  },
  {
    token: "wBNB",
    addressTest: "0xae13d989dac2f0debff460ac112a837c89baa7cd",
    addressLive: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    interestRate: 3.29,
    minimumDeposit: toBN(1, 18),
  },
  {
    token: "wETH",
    addressTest: "0xf670e09e0221a4100fbc83f4f49eda6e7bc923b0",
    addressLive: "0x2170ed0880ac9a755fd29b2688956bd959f933f8",
    interestRate: 3.29,
    minimumDeposit: toBN(5, 17),
  },
];

module.exports = async function (deployer, network, [creator]) {
  if (network === "test") return;

  console.log(`Deploying from owner: ${creator}`);

  await deployer.deploy(Migrations);

  const lockUpPool = await deployer.deploy(LockUpPool);
  await lockUpPool.initialize();

  await lockUpPool.transferOwnership(creator);

  for (let i = 0; i < tokenToDeployList.length; i++) {
    const {
      addressTest,
      addressLive,
      interestRate,
      minimumDeposit,
    } = tokenToDeployList[i];
    const currentAddress = isLive ? addressLive : addressTest;

    await lockUpPool.addNewToken(
      currentAddress,
      parseInt(interestRate * 100),
      minimumDeposit
    );
  }
};
