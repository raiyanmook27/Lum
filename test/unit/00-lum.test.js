const { expect, assert } = require("chai")
const { ethers, network, getNamedAccounts, deployments } = require("hardhat")
const { readConfigFile } = require("typescript")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Lum Unit Test.", () => {
          let lum, sendValue, vrfCoordinatorMock, interval
          const id_const = "0xb771cd9cffecb27cf78b446990d845eb96f8b414f9bf010fa3e5368f06d92973"
          const chainId = network.config.chainId
          beforeEach(async () => {
              const { deployer } = await getNamedAccounts()
              await deployments.fixture(["all"])
              lum = await ethers.getContract("Lum", deployer)
              vrfCoordinatorMock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
              sendValue = ethers.utils.parseEther("1.0")
              interval = await lum.getInterval()
          })

          describe("constructor", async function () {
              it("initializes time interval", async function () {
                  assert.equal(interval.toString(), networkConfig[chainId]["keepersUpdateInterval"])
              })
          })

          describe("createGroup()", () => {
              beforeEach(async () => {
                  await lum.createGroup("raiyan")
              })
              it("should create an group id", async () => {
                  expect(await (await lum.groupDetails(id_const)).id).to.equal(id_const)
              })
              it("should emit a Group created event", async function () {
                  await expect(lum.createGroup("raiyan")).to.emit(lum, "GroupCreated")
              })
          })
          describe("numberOfGroups()", () => {
              it("should return the number of groups", async function () {
                  await lum.createGroup("raiyan")
                  expect(await lum.numberOfGroups()).to.equal(1)
              })
          })
          describe("getGroupId()", () => {
              it("should return a group id", async function () {
                  await lum.createGroup("raiyan")
                  expect(await lum.getGroupId(0)).to.equal(id_const)
              })
          })
          describe("getNum_Members()", () => {
              it("should return a group id", async function () {
                  await lum.createGroup("raiyan")
                  expect(await lum.getNum_Members()).to.equal(4)
              })
          })

          describe("joinGroup()", () => {
              beforeEach(async function () {
                  accounts = await ethers.getSigners()
              })
              // check if group exist
              it("should revert if group doesn't exist", async () => {
                  await lum.createGroup("raiyanM")
                  await expect(lum.joinGroup(id_const)).to.be.revertedWith("Group doesn't exist")
              })
              //check if members are full
              it("should revert if group is full", async () => {
                  await lum.createGroup("raiyan")
                  for (let i = 1; i < 4; i++) {
                      lum.connect(accounts[i]).joinGroup(id_const)
                  }
                  const address5 = accounts[4]
                  await expect(lum.connect(address5).joinGroup(id_const)).to.be.revertedWith(
                      "Group is full"
                  )
              })
              it("should join a group", async () => {
                  await lum.createGroup("raiyan")
                  const address2 = accounts[1]
                  await lum.connect(address2).joinGroup(id_const)
                  expect((await lum.NumberOfGroupMembers(id_const)).toNumber()).to.equal(2)
              })
              it("should emit a group joined event", async () => {
                  await lum.createGroup("raiyan")
                  await expect(lum.joinGroup(id_const)).to.emit(lum, "GroupJoined")
              })
          })
          describe("DepositFunds()", () => {
              beforeEach(async () => {
                  accounts = await ethers.getSigners()

                  await lum.createGroup("raiyan")
              })
              it("should revert if caller isn't a member", async function () {
                  await expect(
                      lum.connect(accounts[1]).depositFunds(id_const)
                  ).to.be.revertedWithCustomError(lum, "Lum__CallerNonExistent")
              })
              it("should revert if ether not enough", async () => {
                  await expect(lum.depositFunds(id_const)).to.be.revertedWithCustomError(
                      lum,
                      "Lum__NotEnoughEth"
                  )
              })
              it("should revert if member already paid", async function () {
                  await lum.depositFunds(id_const, { value: sendValue })
                  await expect(
                      lum.depositFunds(id_const, { value: sendValue })
                  ).to.be.revertedWithCustomError(lum, "Lum__CallerAlreadyPaid")
              })
              it("should deposit funds to the group account", async function () {
                  await lum.depositFunds(id_const, { value: sendValue })

                  expect(await lum.balanceOf(id_const)).to.equal(sendValue)
              })
              it("should update member payment status", async () => {
                  await lum.depositFunds(id_const, { value: sendValue })
                  expect(await lum.getMemberPaymentStatus(accounts[0].address, id_const)).to.equal(
                      0
                  )
              })
              it("should emit an event when deposit is successful", async () => {
                  await expect(lum.depositFunds(id_const, { value: sendValue })).to.emit(
                      lum,
                      "GroupFunded"
                  )
              })
          })

          describe("checkUpkeep", function () {
              it("should return false if time has passed", async function () {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  const { upkeepNeeded } = await lum.callStatic.checkUpkeep("0x")
                  assert(upkeepNeeded)
              })
          })
          describe("performUpKeep", function () {
              it("should revert if checkUpKeep is false", async function () {
                  await expect(lum.performUpkeep([])).to.be.revertedWithCustomError(
                      lum,
                      "Lum__UpkeepNotNeeded"
                  )
              })
              it("it can only run if checkUpKeep is true", async function () {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  const tx = await lum.performUpkeep([])
                  assert(tx)
              })
              it("should if requestId is available", async function () {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  const txResponse = await lum.performUpkeep([])
                  const txReceipts = await txResponse.wait(1)
                  const requestId = txReceipts.events[1].args.requestId
                  assert(requestId.toNumber() > 0)
              })
          })

          describe("fulfillRandomWords", function () {
              beforeEach(async function () {
                  await network.provider.send("evm_increaseTime", [interval.toNumber() + 1])
                  await network.provider.send("evm_mine", [])
                  await lum.startLum(id_const)
              })
              it("can only be called after performUpKeep", async function () {
                  await expect(
                      vrfCoordinatorMock.fulfillRandomWords(0, lum.address)
                  ).to.be.revertedWith("nonexistent request")
              })
              it("picks a user address at random from a group", async () => {
                  await lum.createGroup("raiyan")
                  await lum.depositFunds(id_const, { value: sendValue })
                  accounts = await ethers.getSigners()
                  const lummers = 4
                  console.log(`Lummer Address ${0} : ${accounts[0].address}`)
                  for (let i = 1; i < lummers; i++) {
                      await lum.connect(accounts[i]).joinGroup(id_const)
                      await lum.connect(accounts[i]).depositFunds(id_const, { value: sendValue })
                      console.log(`Lummer Address ${i} : ${accounts[i].address}`)
                  }

                  const startingTimeStamp = await lum.get_TimeStamp()
                  let endingTime
                  //listener for events
                  await new Promise(async (resolve, reject) => {
                      lum.once("lummerAddressPicked", async () => {
                          console.log("found Event")

                          try {
                              const lumAddress = await lum.getLummAddress()
                              console.log("Random Lummer Address:", lumAddress)
                              endingTime = await lum.get_TimeStamp()
                              assert(endingTime > startingTimeStamp)
                          } catch (e) {
                              reject(e)
                          }
                          resolve()
                      })

                      const tx = await lum.performUpkeep([])
                      const txReceipts = await tx.wait(1)
                      await vrfCoordinatorMock.fulfillRandomWords(
                          txReceipts.events[1].args.requestId,
                          lum.address
                      )
                  })
              })
          })
      })
