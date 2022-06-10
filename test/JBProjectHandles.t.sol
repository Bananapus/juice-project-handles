// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";

import '@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol';
import '@jbx-protocol/contracts-v2/contracts/JBProjects.sol';
import '@jbx-protocol/contracts-v2/contracts/JBOperatorStore.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

import "@contracts/JBProjectHandles.sol";
import "@contracts/structs/ENSName.sol";
import "@contracts/libraries/JBHandlesOperations.sol";

contract ContractTest is Test {
    // For testing the event emitted
    event SetEnsName(uint256 indexed projectId, string indexed ensName);

    address projectOwner = address(6942069);

    ITextResolver ensTextResolver = ITextResolver(address(69420)); // Mocked
    JBOperatorStore jbOperatorStore;
    JBProjects jbProjects;
    JBProjectHandles projectHandle;

    function setUp() public {
        vm.etch(address(ensTextResolver), '0x69');
        vm.label(address(ensTextResolver), 'ensTextResolver');
        jbOperatorStore = new JBOperatorStore();
        jbProjects = new JBProjects(jbOperatorStore);
        projectHandle = new JBProjectHandles(jbProjects, jbOperatorStore, ensTextResolver);
    }

    //*********************************************************************//
    // ------------------------ SetEnsNameFor(..) ------------------------ //
    //*********************************************************************//

    function testSetEnsNameFor_passIfProjectOwner(string memory _name) public {
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // Test the event emitted
        vm.expectEmit(true, true, false, true);
        emit SetEnsName(_projectId, _name);

        vm.prank(projectOwner);
        projectHandle.setEnsNameFor(_projectId, _name);

        // Control: correct ENS name?
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: _name, subdomain:''}));
    }

    function testSetEnsNameFor_passIfAuthorized(address caller, string calldata _name) public {
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // Give the authorisation to set ENS to caller
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = JBHandlesOperations.SET_ENS_NAME_FOR;

        vm.prank(projectOwner);
        jbOperatorStore.setOperator(JBOperatorData({
            operator: caller,
            domain: 1,
            permissionIndexes: permissionIndexes
        }));

        // Test event
        vm.expectEmit(true, true, false, true);
        emit SetEnsName(_projectId, _name);

        vm.prank(caller);
        projectHandle.setEnsNameFor(_projectId, _name);

        // Control: correct ENS name?
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: _name, subdomain:''}));
    }

    function testSetEnsNameFor_revertIfNotAuthorized(uint96 authorizationIndex, address caller, string calldata _name) public {
        vm.assume(authorizationIndex != JBHandlesOperations.SET_ENS_NAME_FOR && authorizationIndex < 255);
        vm.assume(caller != projectOwner);
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // Is the caller not authorized by default?
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNameFor(_projectId, _name);

        // Still noot authorized if wrong permission index
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = authorizationIndex;

        vm.prank(projectOwner);
        jbOperatorStore.setOperator(JBOperatorData({
            operator: caller,
            domain: 1,
            permissionIndexes: permissionIndexes
        }));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNameFor(_projectId, _name);

        // Control: ENS is still empty
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: '', subdomain:''}));
    }

    //*********************************************************************//
    // ------------------ setEnsNameWithSubdomainFor(..) ----------------- //
    //*********************************************************************//

    function testSetEnsNameWithSubdomainFor_passIfProjectOwner(string calldata _name, string calldata _subdomain) public {
        vm.assume(bytes(_name).length > 0 && bytes(_subdomain).length > 0);
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // SUBDOMAIN.NAME.ETH for event testing
        string memory fullName = string(abi.encodePacked(_subdomain, '.', _name));

        // Test event
        vm.expectEmit(true, true, false, true);
        emit SetEnsName(_projectId, fullName);

        vm.prank(projectOwner);
        projectHandle.setEnsNameWithSubdomainFor(_projectId, _name, _subdomain);

        // Control: ENS has correct name and domain
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: _name, subdomain: _subdomain}));
    }

    function testSetEnsNameWithSubdomainFor_passIfAuthorized(address caller, string calldata _name, string calldata _subdomain) public {
        vm.assume(bytes(_name).length > 0 && bytes(_subdomain).length > 0);
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // SUBDOMAIN.NAME.ETH for event testing
        string memory fullName = string(abi.encodePacked(_subdomain, '.', _name));

        // Give permission
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = JBHandlesOperations.SET_ENS_NAME_FOR;

        vm.prank(projectOwner);
        jbOperatorStore.setOperator(JBOperatorData({
            operator: caller,
            domain: 1,
            permissionIndexes: permissionIndexes
        }));

        // Test event
        vm.expectEmit(true, true, false, true);
        emit SetEnsName(_projectId, fullName);

        vm.prank(caller);
        projectHandle.setEnsNameWithSubdomainFor(_projectId, _name, _subdomain);

        // Control: ENS has correct name and domain
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: _name, subdomain: _subdomain}));
    }

    function testSetEnsNameWithSubdomainFor_revertIfNotAuthorized(uint96 authorizationIndex, address caller, string calldata _name, string calldata _subdomain) public {
        vm.assume(authorizationIndex != JBHandlesOperations.SET_ENS_NAME_FOR && authorizationIndex < 255);
        vm.assume(caller != projectOwner);
        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));
        
        // Not authorized by default
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNameWithSubdomainFor(_projectId, _name, _subdomain);

        // Not authorized with the wrong permission index
        uint256[] memory permissionIndexes = new uint256[](1);
        permissionIndexes[0] = authorizationIndex;

        vm.prank(projectOwner);
        jbOperatorStore.setOperator(JBOperatorData({
            operator: caller,
            domain: 1,
            permissionIndexes: permissionIndexes
        }));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        projectHandle.setEnsNameWithSubdomainFor(_projectId, _name, _subdomain);

        // Control: No ENS
        assertEq(projectHandle.ensNameOf(_projectId), ENSName({name: '', subdomain: ''}));
    }

    //*********************************************************************//
    // ---------------------------- handleOf(..) ------------------------- //
    //*********************************************************************//

    function testHandleOf_returnsEmptyStringIfNoENSset(uint256 projectId) public {
        // No ENS set -> empty
        assertEq(projectHandle.handleOf(projectId), '');
    }

    function testHandleOf_returnsEmptyStringIfReverseIdDoesNotMatchProjectId(uint256 projectId, uint256 _reverseId, string calldata _name, string calldata _subdomain) public {
        vm.assume(projectId != _reverseId);

        string memory reverseId = Strings.toString(_reverseId);
        string memory KEY = projectHandle.TEXT_KEY();

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector,  _namehash(ENSName({name: _name, subdomain: _subdomain})), KEY),
            abi.encode(reverseId)
        );

        assertEq(projectHandle.handleOf(projectId), '');
    }

    function testHandleOf_returnsHandleIfReverseIdMatchProjectId(string calldata _name, string calldata _subdomain) public {
        vm.assume(bytes(_name).length > 0 && bytes(_subdomain).length > 0);

        uint256 _projectId = jbProjects.createFor(projectOwner, JBProjectMetadata({content: 'content', domain: 1}));

        string memory reverseId = Strings.toString(_projectId);
        string memory KEY = projectHandle.TEXT_KEY();

        vm.prank(projectOwner);
        projectHandle.setEnsNameWithSubdomainFor(_projectId, _name, _subdomain);

        vm.mockCall(
            address(ensTextResolver),
            abi.encodeWithSelector(ITextResolver.text.selector,  _namehash(ENSName({name: _name, subdomain: _subdomain})), KEY),
            abi.encode(Strings.toString(_projectId))
        );

        assertEq(projectHandle.handleOf(_projectId),string(abi.encodePacked(_subdomain, '.', _name)) );
    }

    //*********************************************************************//
    // ---------------------------- helpers ---- ------------------------- //
    //*********************************************************************//

    // Assert equals between two ENSName struct
    function assertEq(ENSName memory _first, ENSName memory _second) internal {
        assertEq(keccak256(bytes(_first.name)), keccak256(bytes(_second.name)));
        assertEq(keccak256(bytes(_first.subdomain)), keccak256(bytes(_second.subdomain)));
    }

    function _namehash(ENSName memory _ensName) internal pure returns (bytes32 namehash) {
            namehash = 0x0000000000000000000000000000000000000000000000000000000000000000;
            namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked('eth'))));
            namehash = keccak256(abi.encodePacked(namehash, keccak256(abi.encodePacked(_ensName.name))));
            if ( bytes(_ensName.subdomain).length != 0 ) {
            namehash = keccak256(
                abi.encodePacked(namehash, keccak256(abi.encodePacked(_ensName.subdomain)))
            );
        }
    }
}
