# ODFI H2DL
# Copyright (C) 2016 Richard Leys  <leys.richard@gmail.com> , University of Karlsruhe  - Asic and Detector Lab Group
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
package provide odfi::h2dl 2.0.0

package require odfi::language 1.0.0
package require odfi::nx::domainmixin
#package require odfi::h2dl::verilog 2.0.0
package require odfi::h2dl::ast  2.0.0
package require odfi::attributes 2.0.0

namespace eval odfi::h2dl {
    
        


    odfi::language::Language define CONNECTING {

        #:connection : HW.Named name {
        #    
        #}

    }
    CONNECTING produceNX


    odfi::language::Language define HW {
        

        ## Elaboration Support 
        ###########################
        +type ElaborationSupport {
            
            :elaboration name {
                +var buildClosure ""

                +method build cl {
                    set :buildClosure [odfi::closures::newITCLLambda $cl]
                }

                +method elaborate args {
                    return [${:buildClosure} apply]
                }
            }

            +method elaborate name {

                ## Get master 
                set master [:master get]
                
                ## Look for name
                puts "looking for elaboration: $name, master is $master" 
                set allElabs [$master shade odfi::h2dl::Elaboration children]
                $allElabs foreach {
                    puts "Elab [$it name get]"
                }
                set elaboration [$master shade odfi::h2dl::Elaboration findChildByProperty name $name]
                if {$elaboration!=""} {
                    puts "Elaborating $elaboration"
                    return [$elaboration elaborate]
                }
            }
        }

        ## Base 
        +type H2DLObject : ElaborationSupport {

            +var file ""
            +var line ""
            +mixin ::odfi::attributes::AttributesContainer

            +method init args {
                next 

                set location  [odfi::common::findUserCodeLocation]
                set :file [lindex $location 0]
                set :line [lindex $location 1]

            }

            ## Common Stuff 
            ##############
            :comment value {

            }
        }

        +type Structural {

        }

        :+type Named  : H2DLObject  {
            
            :+var name false
            :+var description ""

            +method toString args {
                return "[:info class].${:name}"
            }
            
            ## Return only parents with Module hierarchy
            #+method formatHierarchyString separator {

             #   set parents [:shade odfi::h2dl::Module getPrimaryParents]
              #  return [[$parents map { return [$it name get]}] mkString $separator]

            #}

        }

        ## Logic Content 
        #####################
        :logic : H2DLObject  {

            ## Branching
            ##################

            ## IF
            :if : ::odfi::h2dl::Logic condition {
                +builder {
                    set :condition [::odfi::h2dl::ast::buildAST [subst ${:condition}]]
                    :addChild ${:condition} 
                }
            }
            :else : ::odfi::h2dl::Logic {

            } 
            #:if condition body {
#
 #           }

            ## test
            #:match : H2DLObject signal {
            #    :if value body  {


                #}
                #:else body {

                #}
            #}

            ## Case 
            :case : H2DLObject signals {
                +builder {
                    set :signals [odfi::flist::MutableList fromList [subst ${:signals}]]
                }
                :on : H2DLObject value {

                }
                :default {

                }
            }

        }
        


        ## Master / Instance 
        ######################

        ## This Type is a marker for an actual master instance 
        +type Master  : H2DLObject {

            +var baseClass "-"

            +method buildInstance node {
                next
                #puts "IN MASTER [:info class], configuring instance $node"
            }

            +method createInstance name {

                
                set newNode [:doCreateInstance $name] 

                $newNode object mixins add Instance
                catch {$newNode mixins delete Master}

                ## Set master 
                $newNode master set [current object]
                $newNode addChild [current object]
                #$newNode addParent [current object]
                    
                puts "Creating Instance of [:info class], $newNode"

                return $newNode
                #return [${:baseClass} createInstance]
            }

            +method doCreateInstance name {
                next
            }
        }

        ## This Type is used to produce masters
        +type MasterSupported : H2DLObject {
            
            +builder {
                

                ## Get Target Class 
                set targetClass [:info class]
                set masterName  [:getMasterName]
                set targetMasterObject ${masterName}_Master

                #puts "(master) INSIDE Master builder for [:name get], the target class is [:info class] and master name: $targetMasterObject"

                #return
                ## Idea:    
                ##   - Look for an Object with name: (CLASS)Master
                ##   - If not available, create the instance with the class as superclass, and build it
                ##   - Add Master as parent to this Instance 
                ##   - Further Building of this instance continues, subclasses can decide what to do
                if {![::nsf::is object $targetMasterObject ]} {

                    ## Copy Object 
                    puts "(master) -- creating master object $targetMasterObject : Using actual instance [current object] as copy --- "
                    #::set  $targetMasterObject [[current object] copy $targetMasterObject]
                    [current object] copy $targetMasterObject

                    ## Build 
                    odfi::closures::protect targetMasterObject
                    $targetMasterObject object mixins add odfi::h2dl::Master
                    $targetMasterObject name set $targetMasterObject
                    $targetMasterObject baseClass set $targetClass
                    $targetMasterObject buildMaster
                    odfi::closures::restore targetMasterObject

                    puts "(master) -- DONE creating master object $targetMasterObject--- "

                     #puts "(master) Done"
                }

                ## Add Actual as child to Master
                $targetMasterObject addChild [current object]
                
                #[current object] public object method master args "return $targetMasterObject"
                [current object] object mixins add Instance
                [current object] master set $targetMasterObject
                $targetMasterObject buildInstance [current object]

                ## Build as Instance 
                #puts "Build instance of $targetMasterObject [current object]"
                #:buildInstance


            }

            +method getMasterName args {
                error "Please implement this function because one base class can trigger multiple masters depending on the input parameters"
            }

            +method buildMaster args {
                error "Please implement to build the master"
            }

            +method buildInstance args {
                next
            }
        }

        +type Instance : H2DLObject  {
            +var master ""



        }
        

        +type InstanceSupport {

            ## Filter out masters
            +method findFirstInstanceInHierarchy args {
                return [:findParentInPrimaryLine { expr {[$it isClass odfi::h2dl::Instance] && ![$it isClass odfi::h2dl::Master]}  }]
            }
        }



        ## IO / Signals 
        ####################
        +type Signal : Named {
            +mixin InstanceSupport
            +var  width  1
            +var  offset 0
            +var  type   digital
            +method size value {
                #puts "Defining size as $args"
                :width set $value
            }

            :bit index {
                +unique index
            }

            ## Bit Mapping
            :bitMap expression name {
                +var wire ""
                +builder {
                    
                    ## Get Index/Range from Expression
                    #puts "Bit map expression ${:expression}"
                    set :expression [::odfi::h2dl::ast::buildAST ${:expression}]
                    
                    #puts "Bit map expression ${:expression} -> $expression"
                    
                    #exit
                    ## Create Wire
                    set mappedWire [[[:parent] parent] wire [[:parent] name get]_[:name get]] 
                    uplevel 4 "set [$mappedWire name get] $mappedWire"
                    #puts "Mapped wire is in [[$mappedWire parent] name get]"
                    
                    ## Set Size to wire 
                    if {[${:expression} isClass odfi::h2dl::ast::ASTRange]} {
                        $mappedWire width set [${:expression} getSize]
                    }
                    $mappedWire assign "[:parent] @ ${:expression}"      
                    set :wire $mappedWire     
                }
            }

            ## Assignment 
            :assign expression {
                 +builder {
                     set :expression [::odfi::h2dl::ast::buildAST ${:expression}]
                     :addChild ${:expression}

                 }
            }

            ## Io Transform 
            +method toOutput {{cl ""}} {
                :object mixins add ::odfi::h2dl::Output
                set :type "wire"
                if {$cl!=""} {
                    :apply $cl
                }
                ## Make sure we are in Module parent 
                #set moduleParent [:findParentInPrimaryLine {$it isClass ::odfi::h2dl::Module}]
               # $moduleParent addChild [current object]
            }
        }

        +type WritableSignal : Signal {

            :reset expr {
                +var type "async"
                +method sync args {
                    set :type "sync"
                }
                +method async args {
                    set :type "async"
                }
                +method isSync args {
                    if {${:type}=="sync"} {
                        return true 
                    } 
                    return false
                }
                +method isAsync args {
                    if {${:type}=="async"} {
                        return true 
                    } 
                    return false
                }
                +builder {

                    puts "Building reset with expression ${:expr}"
                    set expr [::odfi::h2dl::ast::buildAST ${:expr}]
                    set :expr $expr

                    :addChild $expr

                    next 
                    return
                    ## FIXME: Idea: Go on all modifiable values on the expression, and add a listener
                    $expr shade ::odfi::h2dl::Register walkDepthFirst {

                        set reg $node 

                        puts "Listening on [$reg name get] for reset value"
                        $reg onChildAdded {

                            set c [:child end]

                        }

                    }
                }
            }

        }


        :+type IO : Signal {
            +var type "wire"
            +var connect ""



            +method register args {
                set :type "reg"
            }
            +method electrical args {
                set :type "electrical"
            }

            ## Connection 
            :connection : Named signal {
                +builder {

                    #puts "Buildign IO connections with ${:signal} "


                    ## Options:
                    ##   - Target signal already has a connection, then take the name 
                    ##   - Target Signal and source Signal have the same parent, just use target signal name 
                    ##   - Target Signal and source Signal don't have the same parent, use the target's parent name prefixed to signal name to make signal look hierarchical
                    ## Checks: 
                    ##   - Check source and target signals are not the same direction

                    ## Set name 
                    #puts "Signal is: ${:signal} [${:signal} info class] "
                    if {[odfi::common::isClass ${:signal} ::odfi::h2dl::IO] || [${:signal} isClass ::odfi::h2dl::Signal]} {
                        set baseSignal [:parent]

                        #puts "using signal "
                        ## If parent from signal and base signal is same, just take the name of the signal
                        ## Otherwise, append the name of the target signal's parent
                        if {[[$baseSignal parent] getPrimaryTreeDepth] == [[${:signal} parent] getPrimaryTreeDepth]} {
                            
                            set :name [[${:signal} parent] name get]_[$signal name get]
                        } else {
                            set :name [$signal name get]
                            #set :name [[${:signal} parent] name get]_[$signal name get]

                            
                        }

                        ## Add target signal 
                        :addChild ${:signal}

                    } else {
                        # Use as string 
                        set :name ${:signal}
                    }
                    ## Check Signal 
                    #if {[[:parent]}
                }
            }
            ## EOF Connection definition
            
            ## If Connection is in parents or child, then signal has a connection
            +method hasConnection args {
                if {[:shade odfi::h2dl::Connection parent]!="" || ![:shade odfi::h2dl::Connection isLeaf]} {
                    return true 
                } else {
                    return false 
                }
            }


            ## Push IO 
            ##############
            
            ## For now, just push up to parent
            +method pushUp {{prefix ""} {cl ""} } {

                set sourceParent [:parent]
                set source [current object]
                set targetParent [$sourceParent shade ::odfi::h2dl::Module parent]

                #puts "push to target parent: $targetParent, source parent: $sourceParent"
                set resultSignal ""
                if {$targetParent!=""} {


                    ## Copy IO 
                    set resultSignal [[current object] copy]

                    ## Rename 
                    if {$prefix!=""} {
                        $resultSignal name set ${prefix}_[$resultSignal name get]
                    }
                    ## Add to parent 
                    $targetParent addChild $resultSignal

                    #$targetParent apply {
                    #    set resultSignal [:input [$sourceParent name get]_[$source name get] $cl]
                    #}

                    ## Make connection 
                    $resultSignal connection $source 

                    ## Copy Attributes 
                    :shade odfi::attributes::AttributeGroup eachChild {
                        $resultSignal addChild [$it copy]
                    }

                }
            }

            ## For now, just push up to parent
            +method pushThrough count {

                set sourceParent [:parent]
                set source [current object]
                set targetParent [$sourceParent parent]
                set resultSignal ""
                set currentCount 0
                set currentName [$sourceParent name get]_[$source name get]
                while {$currentCount<$count && $targetParent!=""} {
                    
                    set currentName [$sourceParent name get]_[$source name get]

                    ## Add to target parent 
                    $targetParent apply {
                        set resultSignal [:input $currentName {

                        }]
                    }

                    ## Make connection 
                    $source connection $resultSignal

                    ## Go to next 
                    set targetParent    [$targetParent parent]
                    set source          [$resultSignal]
                    set sourceParent    [$resultSignal parent]
                    incr currentCount

                    
                    #puts "Push current name $currentName"

                }
            }
        }
        
        :module : Named name {
            
            #+mixin verilog <- odfi::h2dl::verilog::VerilogGen
            +mixin Master

            +mixin ::odfi::h2dl::Logic
            +mixin ::odfi::h2dl::Structural
            +expose name
            +exportTo         ::odfi::h2dl::Module
            +exportToPublic

            #+builder {
               # puts "Inside Module builder [:info class]"
            #}

            ## Master behavior
            #######################

            ## When a parent is added, if it is another module, then create an instance instead
            ## Same After building if we are in a hierarchy
            ## !! Ignore this for now, because unsure it is a whished behavior
            +builder {
                return 

                set postBuildCl {
                    set p [:noShade parent end]
                    
                    ## Only if added to a Module, and we are not a module ourselves already
                    if {$p!=""} {
                        puts "*** Module added a parent [$p info class]"
                        if {[$p isClass odfi::h2dl::Module] && ![:isClass odfi::h2dl::Instance]} {

                            set instance [:createInstance [:name get]_I]
                            #[current object] detach
                            #$p removeChild [current object]
                            $p addChild $instance
                        }
                    }
                }
                :onParentAdded $postBuildCl
                :onBuildDone $postBuildCl
            }

            +method doCreateInstance name {
                #puts "INSIDE DO CREATE INSTANCE $name"
                set newInstance [[:info class] new -name $name]
                
                ## Copy/Import all the IOS
                [:shade odfi::h2dl::IO children] foreach {

                    ## Copy and detach
                    ################
                    set nio [$it copy]

                    $nio clearParents
                    $nio clearChildren

                    ## Rebuild 
                    $nio +build

                    ## Add to current node 
                    $newInstance addChild $nio

                    ## Set base IO as parent to find back original definition later
                    $nio addParent $it

                    ## Res Set IO as class variable again
                    $newInstance object variable -accessor public [$nio name get] $nio

                    ## Transfer Existing Connections 
                    ################
                    ::ignore {
                        $it shade odfi::h2dl::Connection eachChild {
                        {conn i} => 
                        if {[$conn parent]==$it} {
                            $conn detach
                            $nio addChild $conn 
                        } else {
                            $conn clearChildren
                            $conn addChild $nio
                        }
                    }
                    }

                    ## Transfer Attributes 
                    ###############
                    $it shade odfi::attributes::AttributeGroup eachChild {
                        {attrs i} => 
                        #puts "Found Attributes Container on base IO"
                        $nio addChild $attrs
                    }   
                }
                #puts "EOF DO CREATE INSTANCE $name"
                return $newInstance
            }

            ## In case of master behavior
            +method buildInstance node {
                next
                #puts "Module created Instance from master, configure instance $node now"
                #puts "IN MASTER [:info class], configuring instance $node"

                ## Copy/Import all the IOS
                [:shade odfi::h2dl::IO children] foreach {

                    ## Copy and detach
                    set nio [$it copy]

                    $nio clearParents
                    $nio clearChildren

                    ## Rebuild 
                    $nio +build

                    ## Add to current node 
                    $node addChild $nio

                    ## Set base IO as parent to find back original definition later
                    $nio addParent $it

                    ## Res Set IO as class variable again
                    $node object variable -accessor public [$nio name get] $nio
                }
            }

            +method getModelInstanceName args {
                return ${:name}
            }

            ## Submodules 
            #:submodule : Module 

            ## IO and signals 
            :input : IO name {
               +expose name  
               +exposeToObject name            
            }
            
            :output : IO name { 
               +expose  name
               +exposeToObject name  
               +mixin WritableSignal               
            }
            
            :IO.inout name {
                +expose  name
                +exposeToObject name  
                +mixin WritableSignal           

                :highz expr {
                    
                    +builder { 
                        set :expr [::odfi::h2dl::ast::buildAST ${:expr}]
                        :addChild ${:expr}

                        next            
                    }
                }

            }

            :register : WritableSignal name {
                +expose name
                +exportTo ::odfi::h2dl::Logic
                
            }

            :wire : Signal name {
                +expose name
                +exportTo ::odfi::h2dl::Logic
                
                
               
            }

            ## Named Value is like a constant with a name 
            ## Can map to Verilog Define or localparam for example
            :namedValue name value {
                +exportTo ::odfi::h2dl::Logic
            }

            :+type SyncBlock : Logic  {

                :reset signal {

                }

                +method doReset res {
                    #set :reset $res
                    :reset $res {

                    }
                    :onBuildDone {

                        ## Setting Up Reset 
                        puts "Setting up reset for Stage-------------------------"

                        ## Content 
                        #set content [:shade odfi::h2dl::ast::ASTNode children]
                        set content [:shade {$it notClass odfi::h2dl::Reset} children]
                         $content foreach {
                                $it detachFrom [current object] 
                        }
                        
                        #$fullContent foreach {
                        #    puts "Full Content to move: [$it info class]"
                        #}
                        
                        ## Add Reset Values for Registers  to Reset if 
                        ## Rest of the logic for the else node
                        :if {<% return $res %> == 0} {

                            $content foreach {
                                $it walkDepthFirstPostorder -level 1 {
                                    if {[$node isClass odfi::h2dl::ast::ASTNonBlockingAssign]} {

                                        [$node firstChild] <= 0
                                        return false 
                                    }
                                    return true
                                }
                                
                            }
                        }
                        :else {
                            $content foreach {
                                #$it detachFrom 
                                #puts "Setting first parent: [$it info class] [[current object] info class]"
                                $it setFirstParent [current object]
                            }
                        }
                    }
                }
            }
            :posedge : SyncBlock signal {
                #+type Logic
            }

            :negedge : SyncBlock signal {
                #+type Logic
            }

            ## Analog names 
            :analog : Signal name {
                +expose name
            }


            ## Stage Block 
            #######################
            :stage : Posedge name signal {
                +exportTo Logic
                +mixin ::odfi::h2dl::Structural
                #+var reset ""

                +builder {

                    ## Signal Can be an expression 
                    set :signal [::odfi::h2dl::ast::buildAST [subst ${:signal}] ]

                    ## Transform to negedge if necessary
                    if {[${:signal} isClass odfi::h2dl::ast::ASTNegate]} {
                        set :signal [${:signal} firstChild]
                        :object mixins add ::odfi::h2dl::Negedge
                    }
                    :onBuildDone {

                        ## Get All Signals and Move them up 
                        set signals [:shade odfi::h2dl::Signal children ]

                        ## Move them to parent, and change the name 
                        $signals foreach {
                            $it detachFrom [current object]
                            $it setFirstParent [:parent]
                            $it name set [:name get]_stage_[$it name get]
                        }

                    }
                }

                +method negedge args {
                    :object-mixins add [namespace current]::Negedge
                }
                
                

            }

            
        }
         
        
    }
    HW produceNX
   


    namespace eval fsm {

        odfi::language::Language default {

            :fsm : ::odfi::h2dl::Logic name {
                +exportTo ::odfi::h2dl::Logic
                +expose name
                #:input name default {
                #    +expose
                #}
                #:output name {
                #    +expose
                #}

                +builder {
                    :onBuildDone {

                        set states [odfi::flist::MutableList new]
                        :shade ::odfi::h2dl::fsm::State walkDepthFirstPostorder {
                            $states += $node
                            return true
                        }
                        set vectorSize [expr  [$states size] == 0 ? 0 : int(ceil(log([$states size])/log(2)))]
                        $states foreach {

                            [:parent] namedValue [$it name get] ${vectorSize}'d$i
                          
                        }

                    }
                }

                :state name {
                    +exportTo State
                    +var initial false
                    #+var values
                    #+method value {output value} {
                    #    lappend :values $output $value
                    #}
                    :goto to {
                        :on expression {
         
                            +builder {
                                set :expression [::odfi::h2dl::ast::buildAST ${:expression}]

                                #puts "Left: [${:expression} firstChild]"
                                #puts "Rifht: [${:expression} lastChild]"
                            }
                        } 

                        ## Something to be done when this transition is matched
                        :do {

                        }
                    }

                    ## Progress Construct is used to got to first defined state
                    :progressOn conditions {

                        +builder {
                            [:parent] onBuildDone {
                              
                           # puts "------- Doing progress with size [[:children] size]"
                            set states [:shade odfi::h2dl::fsm::State children]
                            if {[$states size]>1 || [$states size]==0} {
                                odfi::log::error "Progress utility can only be used if one sub-state is defined"
                            } else {
                                set targetState [$states first]
                                set progressNode [:shade odfi::h2dl::fsm::ProgressOn firstChild]
                                :goto [$targetState name get] {
                                    #foreach expr [$progressNode conditions get] {
                                       # puts "On Expression: [$progressNode conditions get]"
                                        :on [$progressNode conditions get] {

                                        }
                                    #}
                                }
                            }
                        }
                        }
                        
                        
                    }

                    :do : ::odfi::h2dl::Logic {

                    }

                    :entering  : ::odfi::h2dl::Logic {

                    }

                    :leaving  : ::odfi::h2dl::Logic {

                    }

                    :oppositePhase : ::odfi::h2dl::Logic {

                    }
                }

                +method toModule parent {

                }

                +method toCase tparent {
                    
                    puts "Produce a Case "
                    set fsm [current object]
                    ## First: Take out the registers 
                    ##########
                    :shade ::odfi::h2dl::Signal eachChild {
                        $it detachFrom $fsm
                        $tparent addChild $it
                    }

                    ## Gather All States 
                    #############
                    set states [odfi::flist::MutableList new]
                    :shade ::odfi::h2dl::fsm::State walkDepthFirstPostorder {
                        #puts "Found State"
                        $states += $node
                        return true
                    }

                    ## Size of vector 
                    set size [$states size]
                    set vectorSize [expr $size == 0 ? 0 : int(ceil(log($size)/log(2)))]
                    #puts "$size States -> $vectorSize"

                    ## Add State Vector 
                    $tparent register [:name get]_state {
                        :width set $vectorSize
                    }

                    ## Find Inputs 
                    #########
                    set inputs [odfi::flist::MutableList new]
                    #:walkDepthFirstPostorder {
                    #    if {[$node isClass ::odfi::h2dl::fsm::On]} {
                    #        puts "Found On condition with expression: [$node expression get] ([[$node expression get] info class]), first child [[$node expression get] firstChild]"
                    #    }
                    #}
                    :shade ::odfi::h2dl::fsm::On walkDepthFirstPostorder {
                        #puts "Found On condition with expression: [$node expression get] ([[$node expression get] info class]), first child [[$node expression get] shade odfi::h2dl::Signal firstChild]"
                        $inputs += [[$node expression get] firstChild]
                    }
                    set inputs [$inputs compact]
                    #puts "Found Conditions: [$inputs size]"


                    set inputVectorSize [expr [$inputs size] == 0 ? 1 : int(ceil(log([$inputs size])/log(2)))]

                    ## Add input Vector 
                    #$tparent wire [:name get]_inputs {
                    #    :width set $inputVectorSize
                    #}

                    ## Second: Create State Case 
                    #######################
                    set stateRegister [set [:name get]_state]
                    $tparent case [concat [set [:name get]_state] [$inputs toTCLList]] {

                        ## Doc 
                        :comment "---- FSM [$fsm name get] : State Case"
                        :comment "-----------"
                        set mainCase [current object]

                        ## Set Cases for each State 
                        $states foreach {
                            {state i} => 

                                ## Default On:
                                ##   - Stay on state or go somewhere else if a transition is defined as default 
                                ##   - Add 

                                ## Get Do 
                                set dos [$state shade ::odfi::h2dl::fsm::Do  children]

                                ## Create On 
                                #set on [:on "{$i,[lrepeat [$inputs size] x]}" {

                                #}]
                                ##$on description set

                                ## Add Dos to on
                                #$dos foreach { $on addChild $it}

                                ## Transitions 
                                ###################
                                $state shade ::odfi::h2dl::fsm::Goto eachChild {

                                    {goto gototi} => 

                                        puts "Found a transition to create an on for"

                                        ## Construct base input value 
                                        set inputValue [lrepeat [$inputs size] x]

                                        ## Find all Ons for this transition 
                                        $goto shade ::odfi::h2dl::fsm::On eachChild {
                                            
                                            {on oni} => 

                                                ## Get Target input and value 
                                                set onExpression [$on expression get]
                                                set targetInput [$onExpression firstChild]
                                                set value 0 
                                                if {[$onExpression isClass ::odfi::h2dl::ast::ASTNegate]} {
                                                    set value 0
                                                } elseif {[$onExpression isClass ::odfi::h2dl::ast::ASTCompare] && [[$onExpression lastChild] isClass ::odfi::h2dl::ast::ASTConstant] } {
                                                    set value [[$onExpression lastChild] constant get]
                                                }  else {
                                                    error "Transition on can only be an expression negating a signal or comparing to a constant"
                                                }

                                                ## Replace inputValue x with this inputvalue 
                                                set inputIndex [$inputs indexOf $targetInput]
                                                set inputValue [lreplace $inputValue $inputIndex $inputIndex $value]

                                        }
                                        ## EOF Search all conditions 


                                        ## Create an on for the transition 
                                        ###############

                                        ## Get the entering of the target state 
                                        set targetState [$states find { expr {[$it name get] } == { [$goto to get] } } ]
                                        set requirements [[$targetState shade ::odfi::h2dl::fsm::Entering children] map {
                                            #puts "Filtering BA in requirement: [[$it children] size]"
                                            return [$it shade ::odfi::h2dl::ast::ASTBlockingAssign children]
                                        }]

                                        ## Get the leaving of current state 
                                        ##########
                                        set leavings [[$state shade ::odfi::h2dl::fsm::Leaving children] map {
                                            #puts "Filtering BA in requirement: [[$it children] size]"
                                            return [$it shade { expr [$it isClass ::odfi::h2dl::ast::ASTBlockingAssign] || [$it isClass ::odfi::h2dl::ast::ASTNonBlockingAssign] } children]
                                        }]

                                        ## Add the Dos of the Transition 
                                        $leavings import [[$goto shade ::odfi::h2dl::fsm::Do children] map {
                                            #puts "Filtering BA in requirement: [[$it children] size]"
                                            return [$it shade { expr [$it isClass ::odfi::h2dl::ast::ASTBlockingAssign] || [$it isClass ::odfi::h2dl::ast::ASTNonBlockingAssign] } children]
                                        }]

                                        #puts "Setting UP Case option for transition to [$goto to get], state register is $stateRegister -> [$stateRegister name get]"
                                        #puts "Found requirements: [$requirements size]"
                                        set joinedVal [join $inputValue ""]
                                        $mainCase on "{ [$state name get] , [llength $inputValue]\'b$joinedVal }" {
                                           #[[lindex$mainCase signals get
                                           
                                           :comment "Case to go to state [$goto to get]"
                                           $stateRegister <= $goto

                                           :comment "Leaving\n"
                                           $leavings foreach {
                                            
                                                $it foreach {
                                               
                                                    set nb [::odfi::h2dl::ast::ASTNonBlockingAssign new]
                                                    $nb addChild [$it firstChild]
                                                    $nb addChild [$it lastChild]
                                                    #$it detach
                                                    :addChild $nb
                                                }
                                            }

                                           :comment "Requirements\n"
                                           $requirements foreach {
                                            {req i} => 
                                             puts "In Requirement, nbs: [$req size]"
                                             $req foreach {
                                               
                                                set nb [::odfi::h2dl::ast::ASTNonBlockingAssign new]
                                                $nb addChild [$it firstChild]
                                                $nb addChild [$it lastChild]
                                                $it detach
                                                :addChild $nb
                                             }
                                           }


                                        }


                                }
                        }
                    }

                    ## Third: Create the DataPath Case 
                    #################
                    $tparent case [concat [set [:name get]_state]] {

                        :comment "---- FSM [$fsm name get] : DataPath Case"
                        :comment "-----------"

                        ## Gather All DO 
                        ############
                        set dos [odfi::flist::MutableList new]
                        :shade ::odfi::h2dl::fsm::Do walkDepthFirstPostorder {
                            $dos += $node
                        }
                        if {[$dos size]==0} {
                            [current object] detach
                        }


                    }

                }
            }

        }
        #odfi::h2dl::Module domain-mixins add odfi::h2dl::fsm::Fsm
        
    }
    
    
    odfi::language::Language define TESTBENCH {
        
        :testbench name {
            +type Module
            +var  test
        }
        
    }




    ## Wrapper for better module definition
    ## args: {PARAMETER VALUE}* CLOSURE
    ## Last element of args will be the closure
    ## The Closure will be used as builder
    proc ModuleDefinition {name args} {

        set closure [lindex $args end]
        set args [lrange $args 0 end-1]

        #puts "Module Def with args: $args"

        #odfi::language::Language default {
#
        #    :$name : ::odfi::h2dl::Module name {
#
         #       +builder $closure
#
       #     }
        #}:+exportToParent

        ## Args will be used as parameters to customise the Model Instance Name
        ##############
        set argsNames {}
        foreach arg $args {
           lappend argsNames "[lindex $arg 0]\${:[lindex $arg 0]}" 
        }
        set argsNames [join $argsNames _]

        set instanceNameMethod "
            +method getMasterName args {
                return \[lindex \[split \[:info class\] :\] end\]_$argsNames
            }
        "

       # puts "Model Definition $name with model instance name : $instanceNameMethod and cl $closure"

        set builder {

            ## Check if there is a master
            ## If not, keep building
            #set masterParent [:shade odfi::h2dl::Master parent]
            #if {$masterParent!=""} {
            #    puts "Building Module Instance ${:name} with parent, only keeping IOs"
            #} else {
            #    <% return $closure %>
            #}
        }
        #[odfi::richstream::embeddedTclFromStringToString $builder]
        set code "
           odfi::language::Language default {

            :$name : ::odfi::h2dl::Module  name $args {

                #puts \"Inside module def with args \${args}\"
                :$instanceNameMethod
                :+exportToParent 
                :+expose name
                :+superclass  ::odfi::h2dl::MasterSupported
                +method buildMaster args {
                    $closure
                }
                +builder {
                    #puts \"Building \[:info class\]\"
                    #puts \"(MDEF) Inside builder of module def \[:info class\]\"
                    
                }


            }
        }
        "

        #puts "Created MDef with $code "
        uplevel $code
        #uplevel [list odfi::language::Language default [list \
        #    :$name : ::odfi::h2dl::Module name $args [list \
        #    :+builder $closure ; \
        #     ] \
         #   ]]


    }
     

    ##################################
    ## Value Expressions
    ##################################
    nx::Class create ValueHolder  {
        WritableSignal mixins add ValueHolder
        Analog mixins add ValueHolder
        Bit    mixins add ValueHolder


        :public method <= args {

            #puts "Expression for Updating [:name get] $args"
            
            ## Create Node for this update 
            set astNode [::odfi::h2dl::ast::ASTNonBlockingAssign new]

            ## Create Expression node 
            set expressionNode [::odfi::h2dl::ast::buildAST $args]
            $expressionNode  object mixins add odfi::flextree::utils::StdoutPrinter

#puts "NB expression: [$expressionNode info class]"

            ## Left: Target Register 
            ## Right: Expression
            $astNode addChild [current object]
            $astNode addChild $expressionNode

            #puts "Res: $expressionNode"
            #$expressionNode printAll

            #puts "Calling context: [uplevel 1 :info class]"
            ## Add Update to where it was called 
            uplevel :addChild $astNode

            #:addChild $expressionNode

            return $astNode


        }

        ## NB Assign Format: reg < 0 < 1 expr , updates bit 0 or reg using bit 1 of expression
        :public method < {intoBit keywork fromBit args} {

            ## Create Node for this update 
            set astNode [::odfi::h2dl::ast::ASTNonBlockingAssign new -fromBitRange $fromBit -toBitRange $intoBit]

            ## Create Expression node 
            set expressionNode [::odfi::h2dl::ast::buildAST $args]
            $expressionNode  object mixins add odfi::flextree::utils::StdoutPrinter

            ## Left: Target Register 
            ## Right: Expression
            $astNode addChild [current object]
            $astNode addChild $expressionNode


            ## Add Update to where it was called 
            uplevel :addChild $astNode

            return $astNode

        }   

        :public method = args {

            #puts "Expression for Updating [:name get] $args"
            
            ## Create Node for this update 
            set astNode [::odfi::h2dl::ast::ASTBlockingAssign new]

            #:eachChild {
            #    puts "Child for clk before expr: [$it info class]"
            #}

            ## Create Expression node 
            set expressionNode [::odfi::h2dl::ast::buildAST $args]
            $expressionNode  object mixins add odfi::flextree::utils::StdoutPrinter

            #:eachChild {
            #    puts "Child for clk after expr: [$it info class]"
            #}

            ## Left: Target Register 
            ## Right: Expressio
            set  leftSide     [current object]
            $astNode addChild $leftSide
            $astNode addChild $expressionNode

            #:eachChild {
            #    puts "Child for clk after added to AST expr: [$it info class]"
            #}

            #puts "Res: $expressionNode"
            #$expressionNode printAll

            ## Add Update to where it was called 
            #puts "Calling context: [uplevel 2 :info class]"
            
            #uplevel 2 [list :addChild $astNode]
            uplevel :addChild $astNode

            #:eachChild {
            #    puts "Child for clk after added to uplevel: [$it info class]"
            #}

            return $astNode

            

            #:addChild $expressionNode

            ## Return node 
            return $astNode

        }
    }

    
}


