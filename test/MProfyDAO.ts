import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("MProfyDAO", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {

    const [owner,dto,to,tadto,no,c1,c2,c3,c4,c5,u1,u2] = await hre.ethers.getSigners();

    const MProfyDAO = await hre.ethers.getContractFactory("MProfyDAO");
    const DeedToken = await hre.ethers.getContractFactory("DeedToken");
    const TreasuryToken = await hre.ethers.getContractFactory("TreasuryToken");
    const dta = await (await DeedToken.deploy()).getAddress();
    const tta = await (await TreasuryToken.deploy()).getAddress();

    const mprofydao = await MProfyDAO.deploy([dta,tta,[c1,c2,c3,c4,c5]]);

    return { mprofydao,owner,dto,to,tadto,no,c1,c2,c3,c4,c5,u1,u2 };
  }

  describe("Testing", function () {
  });
});
