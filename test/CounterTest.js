const { expect } = require("chai");
const { ethers } = require("hardhat");


const {
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
describe("Counter contract", function () {

    async function deployTokenFixture() {
        const [owner] = await ethers.getSigners();

        const hardhatCounter = await ethers.deployContract("Counter");

        await hardhatCounter.waitForDeployment();

        return { hardhatCounter, owner };
    }
    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { hardhatCounter, owner } = await loadFixture(deployTokenFixture);
            await hardhatCounter.setNumber(1)
            expect(await hardhatCounter.getNumber()).to.equal(1);
        });

    });


})
