import ICRC72OrchestratorService "../../icrc72-orchestrator.mo/src/service";

import TT "../../timerTool/src/";

import ICRC72Subscriber "../../icrc72-subscriber.mo/src/";
import ICRC72SubscriberService "../../icrc72-subscriber.mo/src/service";
import ICRC72BroadcasterService "../../icrc72-broadcaster.mo/src/service";
import ICRC72Publisher "../../icrc72-publisher.mo/src/";
import ICRC75Service "../../ICRC75/src/service";
import ICRC10 "mo:icrc10-mo";
import ClassPlus "../../../../ICDevs/projects/ClassPlus/src/";
import base16 "mo:base16/Base16";


import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import D "mo:base/Debug";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Timer "mo:base/Timer";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Vector "mo:vector";
import ICRC75 "../../ICRC75/src/";
import CertTree "mo:ic-certification/CertTree";
import AccountIdentifier "mo:account-identifier";





shared (deployer) actor class Subscriber<system>(args: ?{
  orchestrator : Principal;
  icrc72SubscriberArgs : ?ICRC72Subscriber.InitArgs;
  icrc75: ICRC75.InitArgs;
  ttArgs : ?TT.Args;
})  = this {

  let debug_channel = {
    var timerTool = true;
    var icrc72Subscriber = true;
    var announce = true;
    var init = true;
  };

  public type DataItemMap = ICRC75Service.DataItemMap;
  public type ManageRequest = ICRC75Service.ManageRequest;
  public type ManageResult = ICRC75Service.ManageResult;
  public type ManageListMembershipRequest = ICRC75Service.ManageListMembershipRequest;
  public type ManageListMembershipRequestItem = ICRC75Service.ManageListMembershipRequestItem;
  public type ManageListMembershipAction = ICRC75Service.ManageListMembershipAction;
  public type ManageListPropertyRequest = ICRC75Service.ManageListPropertyRequest;
  public type ManageListMembershipResponse = ICRC75Service.ManageListMembershipResponse;
  public type ManageListPropertyRequestItem = ICRC75Service.ManageListPropertyRequestItem;
  public type ManageListPropertyResponse = ICRC75Service.ManageListPropertyResponse;
  public type AuthorizedRequestItem = ICRC75Service.AuthorizedRequestItem;
  public type PermissionList = ICRC75Service.PermissionList;
  public type PermissionListItem = ICRC75Service.PermissionListItem;
  public type ListRecord = ICRC75Service.ListRecord;
  public type List = ICRC75.List;
  public type ListItem = ICRC75.ListItem;
  public type Permission = ICRC75.Permission;
  public type Identity = ICRC75.Identity;
  public type ManageResponse = ICRC75Service.ManageResponse;

  debug if(debug_channel.init) D.print("CANISTER: Initializing Subscriber");

  let thisPrincipal = Principal.fromActor(this);

  //default args
  let BTree = ICRC72Subscriber.BTree;
  let Map = ICRC72Subscriber.Map;
  type ICRC16 = ICRC72Subscriber.ICRC16;
  type ICRC16Map = ICRC72Subscriber.ICRC16Map;
  type ICRC16Property = ICRC72Subscriber.ICRC16Property;
  type ICRC16MapItem = ICRC72Subscriber.ICRC16MapItem;

  let icrc72SubscriberDefaultArgs = null;
  let ttDefaultArgs = null;

  stable var _owner = deployer.caller;

  let initManager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);

  let icrc72SubscriberInitArgs : ?ICRC72Subscriber.InitArgs = switch(args){
    case(null) icrc72SubscriberDefaultArgs;
    case(?args){
      switch(args.icrc72SubscriberArgs){
        case(null) icrc72SubscriberDefaultArgs;
        case(?val) ?val;
      };
    };
  };

  let ttInitArgs : TT.Args = switch(args){
    case(null) ttDefaultArgs;
    case(?args){
      switch(args.ttArgs){
        case(null) ttDefaultArgs;
        case(?val) val;
      };
    };
  };

  let icrc75_args : ICRC75.InitArgs = do?{args!.icrc75!};
  stable var icrc10 = ICRC10.initCollection();


  let orchestratorPrincipal = switch(args){
    case(?args) args.orchestrator;
    case(null) Principal.fromActor(this);
  };

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    debug if(debug_channel.timerTool) D.print("CANISTER: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    debug if(debug_channel.timerTool) D.print("CANISTER: TimerTool Error: " # debug_show(errInfo));
    return null;
  };

  stable var tt_migration_state: TT.State = TT.Migration.migration.initialState;

  let thisCanister = Principal.fromActor(this);

  let tt  = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = ttInitArgs;
    pullEnvironment = ?(func() : TT.Environment {
      {      
        advanced = null;
        reportExecution = ?reportTTExecution;
        reportError = ?reportTTError;
        syncUnsafe = null;
        reportBatch = null;
      };
    });

    onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
      D.print("Initializing TimerTool");
      newClass.initialize<system>();
      //do any work here necessary for initialization
    });
    onStorageChange = func(state: TT.State) {
      tt_migration_state := state;
    }
  });

  stable var icrc72SubscriberMigrationState : ICRC72Subscriber.State = ICRC72Subscriber.Migration.migration.initialState;

  var errors : Vector.Vector<Text> = Vector.new<Text>();
  var bFoundOutOfOrder : Bool = false;

  let records = Vector.new<([(Text, ICRC72Subscriber.Value)], [(Text, ICRC72Subscriber.Value)])>();

  func addRecord(trx : [(Text, ICRC72Subscriber.Value)], trxTop: ?[(Text, ICRC72Subscriber.Value)]) : Nat{
    Vector.add(records, (trx, switch(trxTop){
      case(?val) val;
      case(null) [];
    }));
    return Vector.size(records);
  };

  public query(msg) func getRecords() : async [([(Text, ICRC72Subscriber.Value)], [(Text, ICRC72Subscriber.Value)])] {
    return Vector.toArray(records);
  };

  let icrc72_subscriber = ICRC72Subscriber.Init<system>({
      manager = initManager;
      initialState = icrc72SubscriberMigrationState;
      args = icrc72SubscriberInitArgs;
      pullEnvironment = ?(func() : ICRC72Subscriber.Environment{
        {      
          advanced = null;
          var addRecord = ?addRecord;
          var icrc72OrchestratorCanister = orchestratorPrincipal;
          tt = tt();
          //5_000_000 call fee
          //260_000 x net call feee
          //1_000 x net byte fee (per byte)
          //127_000 per gbit per second.  
          var handleEventOrder = null;
          var handleNotificationPrice = ?ICRC72Subscriber.ReflectWithMaxStrategy("com.panindustrial.icaibus.message.cycles", 10_000_000_000); 
          var onSubscriptionReady = null;
          var handleNotificationError = ?(func<system>(event: ICRC72Subscriber.EventNotification, error: Error) : () {
            D.print("Error in Notification: " # debug_show(event) # " " # Error.message(error));

            Vector.add(errors, Error.message(error));
            return;
          });
        };
      });

      onInitialize = ?(func (newClass: ICRC72Subscriber.Subscriber) : async* () {
        D.print("Initializing Subscriber");
        ignore Timer.setTimer<system>(#nanoseconds(0), newClass.initializeSubscriptions);
        //do any work here necessary for initialization
      });
      onStorageChange = func(state: ICRC72Subscriber.State) {
        icrc72SubscriberMigrationState := state;
      }
    });


    stable let icrc75_migration_state = ICRC75.migrate(ICRC75.initialState(), #v0_1_1(#id), icrc75_args, _owner);

    let #v0_1_1(#data(icrc75_state_current)) = icrc75_migration_state;

    private var _icrc75 : ?ICRC75.ICRC75 = null;


    private func get_icrc75_state() : ICRC75.CurrentState {
      return icrc75_state_current;
    };

    stable let cert_store : CertTree.Store = CertTree.newStore();
    let ct = CertTree.Ops(cert_store);

    private func getCertStore() : CertTree.Store {
      
      return cert_store;
    };

    stable let fakeLedger = Vector.new<ICRC75.Value>(); //maintains insertion order

    private func fakeledgerAddRecord<system>(trx: ICRC75.Value, trxTop: ?ICRC75.Value) : Nat {

      let finalMap = switch(trxTop){
        case(?#Map(top)) {
          let combined = Array.append<(Text, ICRC75.Value)>(top, [("tx",trx)]);
          #Map(combined);
        };
        case(_) {
          #Map([("op",trx)]);
        };
      };
      Vector.add(fakeLedger, finalMap);
      Vector.size(fakeLedger) - 1;
    };

    private func get_icrc75_environment() : ICRC75.Environment {
    {
      advanced = null;
      tt = ?tt(); // for recovery and safety you likely want to provide a timer tool instance here
      updated_certification = null; //called when a certification has been made
      get_certificate_store = ?getCertStore; //needed to pass certificate store to the class
      addRecord = ?fakeledgerAddRecord;
      icrc10_register_supported_standards = func(a : ICRC10.Entry): Bool {
        ICRC10.register(icrc10, a);
        true;
      };
    };
  };

  func icrc75() : ICRC75.ICRC75 {
    switch(_icrc75){
      case(null){
        let initclass : ICRC75.ICRC75 = ICRC75.ICRC75(?icrc75_migration_state, Principal.fromActor(this), get_icrc75_environment());
        _icrc75 := ?initclass;
        
        initclass;
        
      };
      case(?val) val;
    };
  };


  public shared(msg) func icrc72_handle_notification(items : [ICRC72SubscriberService.EventNotification]) : () {
    debug if(debug_channel.announce) D.print("CANISTER: Received notification: " # debug_show(items));
    return await* icrc72_subscriber().icrc72_handle_notification(msg.caller, items);
  };


  public query(msg) func get_stats() : async ICRC72Subscriber.Stats {
    return icrc72_subscriber().stats();
  };

  public query(msg) func get_subnet_for_canister() : async {
    #Ok : { subnet_id : ?Principal };
    #Err : Text;
  } {
    return #Ok({subnet_id = ?Principal.fromActor(this)});
  };

  public shared(msg) func updateSubscription(request: [ICRC72OrchestratorService.SubscriptionUpdateRequest]) : async [ICRC72OrchestratorService.SubscriptionUpdateResult] {

    if(msg.caller != _owner) D.trap("Unauthorized in update sub");
    return await* icrc72_subscriber().updateSubscription( request);
  };


  public shared(msg) func initRegistration() : async () {
    if(msg.caller != _owner) D.trap("Unauthorized in initRegistration");

    D.print("Initializing Registration");

    let createList = await* icrc75().manage_list_properties(_owner, [{
      list = "com.panidustrial.icaibus.alphaTester";
      action = #Create({
        admin = null;
        metadata = [(
          ("instructions", #Text("Send ICP to e9dc3bbbcb45479709e8ef512f6c8a66d6593cbb1b8621ff9cdbde917d6da9aa to become an alpha Tester. Who knows what may happen!"))
        )];
        members = [];
      });
      memo= null;
      from_subaccount= null;
      created_at_time= null;
    },{
      list = "com.panidustrial.icaibus.alphaTester";
      action = #ChangePermissions(#Read(#Add(#Identity(Principal.fromText("2vxsx-fae")))));
      memo = null;
      from_subaccount = null;
      created_at_time = null;
    }], null);

    D.print("List Created: " # debug_show(createList));

    let subscribeResult = await* icrc72_subscriber().subscribe([{
      namespace = "com.icp.org.trx_stream";
      config = [
        (ICRC72Subscriber.CONST.subscription.filter, #Text("$.to == e9dc3bbbcb45479709e8ef512f6c8a66d6593cbb1b8621ff9cdbde917d6da9aa")),
        (ICRC72Subscriber.CONST.subscription.controllers.list, #Array([#Blob(Principal.toBlob(thisPrincipal)), #Blob(Principal.toBlob(_owner))])),
      ];
      memo = null;
      listener = #Async(
          func <system>(event: ICRC72Subscriber.EventNotification) : async* (){
            D.print("Received Event: " # debug_show(event));
            let #Class(data) = event.data else return;
            let trx = data |>
                       Array.map<ICRC16Property, ICRC16MapItem>(_, func(x) : ICRC16MapItem{(x.name, x.value)}) |>
                       _.vals() |>
                        Map.fromIter<Text,ICRC16>(_, Map.thash);

            D.print(debug_show(trx));
            let ?#Nat(amount) = Map.get<Text,ICRC16>(trx, Map.thash, "amount") else return;
            let ?#Text(from) = Map.get<Text,ICRC16>(trx, Map.thash, "from") else return;
            let ?#Text(spender) = Map.get<Text,ICRC16>(trx, Map.thash, "spender") else return;
            let ?#Nat(ts) = Map.get<Text,ICRC16>(trx, Map.thash, "ts") else return;
            let trxId = switch(Map.get<Text,ICRC16>(trx, Map.thash, "id")){
              case(?#Nat(val)) val;
              case(_) 0;
            };

            D.print("Received Transaction: " # debug_show((amount, from, spender, ts, trxId)));
            
            if(amount > 10_000){

              let foundMember = BTree.get(icrc75().get_state().namespaceStore, Text.compare, "com.panidustrial.icaibus.alphaTester." # from);

              switch(foundMember){
                case(null){
                  //not yet a member
                  let result = await* icrc75().manage_list_properties(_owner, [{
                    list= "com.panidustrial.icaibus.alphaTester." # from;
                    action= #Create({
                      members = [];
                      admin = null;
                      metadata = [];
                    });
                    memo = null;
                    from_subaccount = null;
                    created_at_time = null;
                  },{
                    list = "com.panidustrial.icaibus.alphaTester." # from;
                    action = #ChangePermissions(#Read(#Add(#Identity(Principal.fromText("2vxsx-fae")))));
                    memo = null;
                    from_subaccount = null;
                    created_at_time = null;
                  }], null);
                };
                case(?val){
                  //already a member
                };
              };

              let resultMember = await* icrc75().manage_list_membership(_owner, [{
                list = "com.panidustrial.icaibus.alphaTester";
                action = #Add( #DataItem(#Text(from)));
                memo = null;
                from_subaccount = null;
                created_at_time = null;
              }], null);

              let buildRecord = Buffer.Buffer<ICRC16MapItem>(2);
              buildRecord.add("amount", #Nat(amount));
              buildRecord.add("ts", #Nat(ts));

              if(spender.size() > 0){
                buildRecord.add("spender", #Text(spender));
              };

              if(trxId > 0){
                buildRecord.add("trxId", #Nat(trxId));
              };

              let resultDetail = await* icrc75().manage_list_membership(_owner, [{
                list = "com.panidustrial.icaibus.alphaTester." # from;
                action = #Add( #DataItem(#Map(Buffer.toArray(buildRecord))));
                memo = null;
                from_subaccount = null;
                created_at_time = null;
              }], null);
            }
          });
      
    }]);

    D.print("Subscription Result: " # debug_show(subscribeResult));

    return;
  };

  public query(msg) func icrc75_metadata() : async DataItemMap {
    return icrc75().metadata();
  };

  public shared(msg) func icrc75_manage(request: ManageRequest) : async ManageResponse {
      return icrc75().updateProperties<system>(msg.caller, request);
    };

  public shared(msg) func icrc75_manage_list_membership(request: ManageListMembershipRequest) : async ManageListMembershipResponse {
    return await* icrc75().manage_list_membership(msg.caller, request, null);
  };

  public shared(msg) func icrc75_manage_list_properties(request: ManageListPropertyRequest) : async ManageListPropertyResponse {
    return await* icrc75().manage_list_properties(msg.caller, request, null);
  };

  public query(msg) func icrc75_get_lists(name: ?Text, bMetadata: Bool, cursor: ?List, limit: ?Nat) : async [ListRecord] {
    return icrc75().get_lists(msg.caller, name, bMetadata, cursor, limit);
  };

  public query(msg) func icrc75_get_list_members_admin(list: List, cursor: ?ListItem, limit: ?Nat) : async [ListItem] {
    return icrc75().get_list_members_admin(msg.caller, list, cursor, limit);
  };

  public query(msg) func icrc75_get_list_permissions_admin(list: List, filter: ?Permission, prev: ?PermissionListItem, take: ?Nat) : async PermissionList {
    return icrc75().get_list_permission_admin(msg.caller, list, filter, prev, take);
  };

  public query(msg) func icrc75_get_list_lists(list: List, cursor: ?List, limit: ?Nat) : async [List] {
    return icrc75().get_list_lists(msg.caller, list, cursor, limit);
  };

  public query(msg) func icrc75_member_of(listItem: ListItem, list: ?List, limit: ?Nat) : async [List] {
    return icrc75().member_of(msg.caller, listItem, list, limit);
  };

  public query(msg) func icrc75_is_member(requestItems: [AuthorizedRequestItem]) : async [Bool] {
    return icrc75().is_member(msg.caller, requestItems);
  };

  public shared(msg) func icrc75_request_token(listItem: ListItem, list: List, ttl: ?Nat) : async ICRC75.IdentityRequestResult {
    return icrc75().request_token<system>(msg.caller,listItem, list, ttl);
  };

  public query(msg) func icrc75_retrieve_token(token: ICRC75.IdentityToken) : async ICRC75.IdentityCertificate {
    return icrc75().retrieve_token(msg.caller, token);
  };

  public query(msg) func getICRC75Stats() : async ICRC75.Stats {
    return icrc75().get_stats();
  };

};



