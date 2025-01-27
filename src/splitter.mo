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
import CertTree "mo:ic-certification/CertTree";
import AccountIdentifier "mo:account-identifier";
import Ledger "./ledger";
import Nat64 "mo:base/Nat64";





shared (deployer) actor class Subscriber<system>(args: ?{
  orchestrator : Principal;
  icrc72SubscriberArgs : ?ICRC72Subscriber.InitArgs;
  ttArgs : ?TT.Args;
})  = this {

  let debug_channel = {
    var timerTool = true;
    var icrc72Subscriber = true;
    var announce = true;
    var init = true;
  };


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
          var addRecord = null;
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




    /* stable let fakeLedger = Vector.new<ICRC75.Value>(); //maintains insertion order

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
    }; */

   
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

  let thisAccount = base16.encode(AccountIdentifier.accountIdentifier(thisPrincipal, AccountIdentifier.defaultSubaccount()));

  public query func this_account() : async Text {
    return thisAccount;
  };


  public shared(msg) func initRegistration() : async () {
    if(msg.caller != _owner) D.trap("Unauthorized in initRegistration");

    let subscribeResult = await* icrc72_subscriber().subscribe([{
      namespace = "com.icp.org.trx_stream";
      config = [
        (ICRC72Subscriber.CONST.subscription.filter, #Text("$.to == " # thisAccount)),
        (ICRC72Subscriber.CONST.subscription.controllers.list, #Array([#Blob(Principal.toBlob(thisPrincipal)), #Blob(Principal.toBlob(_owner))])),
      ];
      memo = null;
      listener = #Async(
          func <system>(event: ICRC72Subscriber.EventNotification) : async* () {
              D.print("Received Event: " # debug_show(event));
              let #Class(data) = event.data else return;
              
              // build a map from event data
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

              // Existing logic: If amount > 10,000 do some membership checks 
              // and record-keeping in ICRC75. (You can keep or remove that logic.)
              if (amount > 10_000) {
                  // ...
                  // membership logic, etc.
              };

              let icrc75 : ICRC75Service.Service = actor("wujau-jyaaa-aaaae-qajxq-cai");
              let icrc75Result = await icrc75.icrc75_get_list_members_admin("com.panidustrial.icaibus.alphaTester", null, null);

               D.print("ICRC75 Result: " # debug_show(icrc75Result));

              

              // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              // NEW: Split the amount among the addresses in loadedAddresses
              // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
              if (icrc75Result.size() > 0) {
                  let n = icrc75Result.size();
                  if(n*10000 > amount) {
                    D.print("Amount too small to split");
                    return;
                  };
                  let splitted = (amount - (n*10000)) / n;   // integer division
                  if(splitted < 1) {
                      D.print("Amount too small to split");
                      return;
                  };
                  D.print(
                      "Splitting " 
                      # Nat.toText(amount) 
                      # " into " 
                      # Nat.toText(n) 
                      # " parts of " 
                      # Nat.toText(splitted)
                  );

                  // If there's a remainder from integer division, you might
                  // want to handle it (e.g., keep in the canister or send
                  // it to the first address). This example simply discards 
                  // the remainder for brevity.

                  label proc for (addr in icrc75Result.vals()) {
                      D.print("Processing address: " # debug_show(addr));
                      let #DataItem(#Text(address)) = addr else continue proc;
                      // Transfer portion to each address
                      await transferICP(splitted, address);
                  };
              };
            
          })}]);

    D.print("Subscription Result: " # debug_show(subscribeResult));

    return;
  };


  private func transferICP(amount : Nat, toAddress : Text) : async () {

    D.print ("Transferring " # Nat.toText(amount) # " ICP to " # toAddress);
    
    let ledger : Ledger.Service = actor(("ryjl3-tyaaa-aaaaa-aaaba-cai"));
    //let ?to = base16.decode(toAddress) else return;

    
    let res = try{
       await ledger.send_dfx(
          {
              from_subaccount = null;
              to = toAddress;
              fee = {e8s= 10_000};     // typical ledger transaction fee in ICP
              memo = 0;         // whatever memo is appropriate
              created_at_time = null;
              amount = {e8s = Nat64.fromNat(amount)};  
          }
      );
    } catch (err) {
      D.print("Error in transferICP: " # Error.message(err));
      return;
    };
    D.print(debug_show(res));

    return;
};



  
};



