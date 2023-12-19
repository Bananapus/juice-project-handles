// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol"; // This is an interface...
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {JBProjects} from "@juicebox/src/JBProjects.sol";
import {JBPermissions} from "@juicebox/src/JBPermissions.sol";
import {JBPermissionsData} from "@juicebox/src/structs/JBPermissionsData.sol";
import "@contracts/JBProjectHandles.sol";
import "@contracts/libraries/JBHandlePermissionIds.sol";

ENS constant ensRegistry = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
IJBProjectHandles constant oldHandle = IJBProjectHandles(0x41126eC99F8A989fEB503ac7bB4c5e5D40E06FA4);

contract ContractTest is Test {
    // For testing the event emitted
    event SetEnsNameParts(uint256 indexed projectId, string indexed ensName, string[] parts, address caller);

    address projectOwner = address(6_942_069);

    ITextResolver ensTextResolver = ITextResolver(address(69_420)); // Mocked
    JBPermissions jbPermissions;
    JBProjects jbProjects;
    JBProjectHandles projectHandle;

    function setUp() public {
        vm.etch(address(ensTextResolver), "0x69");
        vm.etch(address(ensRegistry), "0x69");
        vm.label(address(ensTextResolver), "ensTextResolver");
        vm.label(address(ensRegistry), "ensRegistry");

        jbPermissions = new JBPermissions();
        jbProjects = new JBProjects(address(69));
        projectHandle = new JBProjectHandles(jbProjects, jbPermissions);
    }

    //*********************************************************************//
    // ------------------------ SetEnsNamePartsFor(..) ------------------- //
    //*********************************************************************//

    function testSetEnsNamePartsFor_passIfCallerIsProjectOwnerAndOnlyName(string calldata name) public {
        vm.assume(bytes(name).length != 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](1);
        nameParts[0] = name;

        // Test the event emitted
        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(projectId, name, nameParts, projectOwner);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: correct ENS name?
        assertEq(projectHandle.ensNamePartsOf(projectId), nameParts);
    }

    function testSetEnsNameFor_passIfAuthorizedCallerAndOnlyName(address caller, string calldata name) public {
        vm.assume(bytes(name).length != 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        // Give the authorisation to set ENS to caller
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = JBHandlePermissionIds.SET_ENS_NAME_FOR;

        vm.prank(projectOwner);
        jbPermissions.setPermissionsForOperator(
            projectOwner, JBPermissionsData({operator: caller, projectId: 1, permissionIds: permissionIndexes})
        );

        string[] memory nameParts = new string[](1);
        nameParts[0] = name;

        // Test event
        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(projectId, name, nameParts, caller);

        vm.prank(caller);
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: correct ENS name?
        assertEq(projectHandle.ensNamePartsOf(projectId), nameParts);
    }

    function testSetEnsNameWithSubdomainFor_passIfMultipleSubdomainLevels(
        string memory name,
        string memory subdomain,
        string memory subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length > 0 && bytes(subdomain).length > 0 && bytes(subsubdomain).length > 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        string memory fullName = string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain));

        // Test event
        vm.expectEmit(true, true, true, true);
        emit SetEnsNameParts(projectId, fullName, nameParts, projectOwner);

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(projectHandle.ensNamePartsOf(projectId), nameParts);
    }

    function testSetEnsNameFor_revertIfNotAuthorized(
        uint96 authorizationIndex,
        address caller,
        string calldata name
    )
        public
    {
        vm.assume(authorizationIndex != JBHandlePermissionIds.SET_ENS_NAME_FOR && authorizationIndex < 255);
        vm.assume(caller != projectOwner);
        uint256 projectId = jbProjects.createFor(projectOwner);

        string[] memory nameParts = new string[](1);
        nameParts[0] = name;

        // Is the caller not authorized by default?
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Still noot authorized if wrong permission index
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = authorizationIndex;

        vm.prank(projectOwner);
        jbPermissions.setPermissionsForOperator(
            projectOwner, JBPermissionsData({operator: caller, projectId: 1, permissionIds: permissionIndexes})
        );

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: ENS is still empty
        assertEq(projectHandle.ensNamePartsOf(projectId), new string[](0));
    }

    function testSetEnsNameWithSubdomainFor_RevertIfEmptyElementInNameParts(
        string memory name,
        string memory subdomain,
        string memory subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length == 0 || bytes(subdomain).length == 0 || bytes(subsubdomain).length == 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSignature("EMPTY_NAME_PART()"));
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(projectHandle.ensNamePartsOf(projectId), new string[](0));
    }

    function testSetEnsNameWithSubdomainFor_RevertIfEmptyNameParts() public {
        uint256 projectId = jbProjects.createFor(projectOwner);

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](0);

        vm.prank(projectOwner);
        vm.expectRevert(abi.encodeWithSignature("NO_PARTS()"));
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        // Control: ENS has correct name and domain
        assertEq(projectHandle.ensNamePartsOf(projectId), new string[](0));
    }

    //*********************************************************************//
    // ---------------------------- handleOf(..) ------------------------- //
    //*********************************************************************//

    function testHandleOf_returnsEmptyStringIfNoHandleSet(uint256 projectId) public {
        // No handle set on the previous JBProjectHandle version neither
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(IJBProjectHandles.ensNamePartsOf, (projectId)),
            abi.encode(new string[](0))
        );

        assertEq(projectHandle.handleOf(projectId), "");
    }

    function testHandleOf_returnsHandleFromNewestContractIfRegisteredOnBothOldAndNew(
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length > 0 && bytes(subdomain).length > 0 && bytes(subsubdomain).length > 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        // The name parts stored in the old contract
        string[] memory oldNamePart = new string[](3);
        oldNamePart[0] = "it hurts";
        oldNamePart[1] = "so deprecated that";
        oldNamePart[2] = "I am";

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), KEY),
            abi.encode(Strings.toString(projectId))
        );

        // Mock the registration on the previous version
        vm.mockCall(
            address(oldHandle), abi.encodeCall(IJBProjectHandles.ensNamePartsOf, (projectId)), abi.encode(oldNamePart)
        );

        // Returns the handle from the latest version
        assertEq(projectHandle.handleOf(projectId), string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain)));
    }

    function testHandleOf_returnsEmptyStringIfENSIsNotRegistered(
        uint256 projectId,
        uint256 reverseId,
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    )
        public
    {
        vm.assume(projectId != reverseId);

        // No handle set on the previous JBProjectHandle version
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(IJBProjectHandles.ensNamePartsOf, (projectId)),
            abi.encode(new string[](0))
        );

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(0))
        );

        assertEq(projectHandle.handleOf(projectId), "");
    }

    function testHandleOf_returnsEmptyStringIfReverseIdDoesNotMatchProjectId(
        uint256 projectId,
        uint256 reverseId,
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    )
        public
    {
        vm.assume(projectId != reverseId);

        // No handle set on the previous JBProjectHandle version
        vm.mockCall(
            address(oldHandle),
            abi.encodeCall(IJBProjectHandles.ensNamePartsOf, (projectId)),
            abi.encode(new string[](0))
        );

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), KEY),
            abi.encode(Strings.toString(reverseId))
        );

        assertEq(projectHandle.handleOf(projectId), "");
    }

    function testHandleOf_returnsHandleIfReverseIdMatchProjectId(
        string calldata name,
        string calldata subdomain,
        string calldata subsubdomain
    )
        public
    {
        vm.assume(bytes(name).length > 0 && bytes(subdomain).length > 0 && bytes(subsubdomain).length > 0);

        uint256 projectId = jbProjects.createFor(projectOwner);

        string memory KEY = projectHandle.TEXT_KEY();

        // name.subdomain.subsubdomain.eth is stored as ['subsubdomain', 'subdomain', 'domain']
        string[] memory nameParts = new string[](3);
        nameParts[0] = subsubdomain;
        nameParts[1] = subdomain;
        nameParts[2] = name;

        vm.prank(projectOwner);
        projectHandle.setEnsNamePartsFor(projectId, nameParts);

        vm.mockCall(
            address(ensRegistry),
            abi.encodeWithSelector(ENS.resolver.selector, _namehash(nameParts)),
            abi.encode(address(ensTextResolver))
        );

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector, _namehash(nameParts), KEY),
            abi.encode(Strings.toString(projectId))
        );

        assertEq(projectHandle.handleOf(projectId), string(abi.encodePacked(name, ".", subdomain, ".", subsubdomain)));
    }

    //*********************************************************************//
    // ---------------------------- helpers ---- ------------------------- //
    //*********************************************************************//

    // Assert equals between two string arrays
    function assertEq(string[] memory first, string[] memory second) internal {
        assertEq(first.length, second.length);
        for (uint256 i; i < first.length; i++) {
            assertEq(keccak256(bytes(first[i])), keccak256(bytes(second[i])));
        }
    }

    function _namehash(string[] memory ensName) internal pure returns (bytes32 namehash) {
        namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked("eth"))));

        // Get a reference to the number of parts are in the ENS name.
        uint256 nameLength = ensName.length;

        // Hash each part.
        for (uint256 i = 0; i < nameLength; i++) {
            namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked(ensName[i]))));
        }
    }
}
