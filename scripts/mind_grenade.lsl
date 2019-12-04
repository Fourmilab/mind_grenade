    /*              Fourmilab Mind Grenade

         Designed and implemented in August 2019 by John Walker
                    https://www.fourmilab.ch/
                    fourmilab in Second Life

        For information about the origin and history of the Mind
        Grenade, see:
            https://www.fourmilab.ch/webtools/MindGrenade/

        This program is licensed under a Creative Commons
        Attribution-ShareAlike 4.0 International License.
            http://creativecommons.org/licenses/by-sa/4.0/
        Please see the License section in the "Fourmilab
        Mind Grenade User Guide" notecard included in the
        object for details.  */

    integer commandChannel = 1969; // Command channel in chat
    integer commandH;           // Handle for command channel
    key whoDat = NULL_KEY;      // Avatar who sent command
    integer restrictAccess = 2; // Access restriction: 0 none, 1 group, 2 owner

    float Pitch = 1600;         // Base frequency  (Can't be changed)
    float Tempo = 0.25;         // Tempo in seconds per note
    string Waveform = "sq";     // Waveform identifier
    float Volume = 0.5;         // Volume
    integer Colour = TRUE;      // Coloured lights ?
    integer tuneSelect = 0;     // XOR mask to select tune

    integer shiftReg;           // Shift register
    integer lastNote = 0;       // Last note played
    list shiftHist = [ 0, 0, 0,  0, 0, 0,  0, 0, 0 ];   // Shift register history

    integer running = FALSE;    // Are we running ?

    string helpFileName = "Fourmilab Mind Grenade User Guide";    // Help notecard name

    //  Indices of linked child prims

    list lights;
    list buttons;

    /*  Find a linked prim from its name.  Avoids having to slavishly
        link prims in order in complex builds to reference them later
        by link number.  You should only call this once, in state_entry(),
        and then save the link numbers in global variables.  Returns the
        prim number or -1 if no such prim was found.  Caution: if there
        are more than one prim with the given name, the first will be
        returned without warning of the duplication.  */

    integer findLinkNumber(string pname) {
        integer i = llGetLinkNumber() != 0;
        integer n = llGetNumberOfPrims() + i;

        for (; i < n; i++) {
            if (llGetLinkName(i) == pname) {
                return i;
            }
        }
        return -1;
    }

    //  tawk  --  Send a message to the interacting user in chat

    tawk(string msg) {
        if (whoDat == NULL_KEY) {
            //  No known sender.  Say in nearby chat.
            llSay(PUBLIC_CHANNEL, msg);
        } else {
            llRegionSayTo(whoDat, PUBLIC_CHANNEL, msg);
        }
    }

    //  checkAccess  --  Check if user has permission to send commands

    integer checkAccess(key id) {
        return (restrictAccess == 0) ||
               ((restrictAccess == 1) && llSameGroup(id)) ||
               (id == llGetOwner());
    }

    //  processCommand  --  Process a command

    processCommand(key id, string message) {

        if (!checkAccess(id)) {
            llRegionSayTo(id, PUBLIC_CHANNEL,
                "You do not have permission to control this object.");
            return;
        }

        string lmessage = llToLower(llStringTrim(message, STRING_TRIM));
        list args = llParseString2List(lmessage, [" "], []);    // Command and arguments
        string command = llList2String(args, 0);    // The command

        whoDat = id;                    // Direct chat output to sender of command

        //  Access who                  Restrict chat command access to public/group/owner

        if (command == "access") {
            string who = llList2String(args, 1);

            if (who == "public") {
                restrictAccess = 0;
            } else if (who == "group") {
                restrictAccess = 1;
            } else if (who == "owner") {
                restrictAccess = 2;
            } else {
                tawk("Unknown access restriction \"" + who +
                    "\".  Valid: public, group, owner.\n");
            }

        /*  Channel n                   Change command channel.  Note that
                                        the channel change is lost on a
                                        script reset.  */

        } else if (command == "channel") {
            integer newch = (integer) llList2String(args, 1);
            if ((newch < 2)) {
                tawk("Invalid channel " + (string) newch + ".");
            } else {
                llListenRemove(commandH);
                commandChannel = newch;
                commandH = llListen(commandChannel, "", NULL_KEY, "");
                tawk("Listening on /" + (string) commandChannel);
            }

        //  Help                        Give help information

        } else if (command == "help") {
            llGiveInventory(id, helpFileName);      // Give requester the User Guide notecard

        //  Restart                     Perform a hard restart (reset script)

        } else if (command == "restart") {
            llResetScript();            // Note that all global variables are re-initialised

        //  Set                         Set simulation parameter

        } else if (command == "set") {
            string param = llList2String(args, 1);
            string svalue = llList2String(args, 2);
            float value = (float) svalue;
            integer onoff = svalue == "on";

            if ((param == "colour") || (param == "color")) {    // colour / color
                Colour = onoff;
                updateLights();

            } else if (param == "tempo") {      // tempo: set note length, seconds
                Tempo = value;
                if (running) {
                    llSetTimerEvent(Tempo);
                }

            } else if (param == "tune") {       // tune: select tune (0-15)
                tuneSelect = (integer) svalue;
                if (tuneSelect < 0) {
                    tuneSelect = 0;
                } else if (tuneSelect > 15) {
                    tuneSelect = 15;
                }
                updateButtons();

            } else if (param == "volume") {     // volume: set volume, 0 to 1
                if (value >= 0 && value <= 1) {
                    Volume = value;
                } else {
                    tawk("Volume " + (string) value + " out of range.  Must be between 0 and 1.");
                }
            } else {
                tawk("Unknown variable \"" + param +
                    "\".  Valid: colour, tempo, volume.");
            }

        //  Start                       Start the music

        } else if (command == "start") {
            if (!running) {
                running = TRUE;
                llSetTimerEvent(Tempo);
            }

        //  Status                      Print current status

        } else if (llGetSubString(command, 0, 3) == "stat") {
            tawk("Position: " + (string) llGetPos());
            tawk("Colour: " + (string) Colour + "  Tempo: " + (string) Tempo +
                 "  Volume: " + (string) Volume + "  Tune: " + (string) tuneSelect);
            tawk("Shift register: " + (string) shiftReg +
                 "  History: " + llList2CSV(shiftHist));
            integer mFree = llGetFreeMemory();
            integer mUsed = llGetUsedMemory();
            tawk("Script memory.  Free: " + (string) mFree +
                  "  Used: " + (string) mUsed + " (" +
                  (string) ((integer) llRound((mUsed * 100.0) / (mUsed + mFree))) + "%)");

        //  Stop                        Stop the music

        } else if (command == "stop") {
            if (running) {
                running = FALSE;
                squelch();
                llSetTimerEvent(0);
            }

/*
        //  Test n                      Run built-in test n

        } else if (command == "test") {
            integer n = (integer) llList2String(args, 1);
            if (n == 1) {
            } else if (n == 2) {
            } else if (n == 3) {
            } else {
            }
*/
        } else {
            tawk("Huh?  \"" + message + "\" undefined.  Chat /" +
                (string) commandChannel + " help for the User Guide.");
        }
    }

    //  indexToFile  --  Obtain sound file corresponding to a note index

    string indexToFile(integer index) {
        integer freq = llRound(Pitch / index);
        return Waveform + (string) freq;
    }

    //  randInt  --  Return pseudorandom integer within range

    integer randInt(integer min, integer max) {
        return min + (integer) llFrand(max - (min + 1));
    }

    //  rand31  --  Get pseudorandom value between 1 and 2^31 - 1

    integer rand31() {
        integer low = randInt(1, 65535);
        integer high = randInt(0, 32767);
        return (high << 16) | low;
    }

    /*  shiftR  --  Update the linear feedback shift register.
                    Returns the note index.  */

    integer shiftR() {
        integer b31 = (shiftReg & (1 << 30));
        integer b28 = (shiftReg & (1 << 27));
        integer b0  = (shiftReg &  1       );
        if (b31 != 0) {
            b31 = 1;
        }
        if (b28 != 0) {
            b28 = 1;
        }
        shiftReg = (shiftReg >> 1) | ((b0 ^ b28 ^ b31 ^ 1) << 30);
        return shiftReg >> 27;
    }

    //  Squelch  --  Stop any currently-playing sound

    squelch() {
        llPlaySound(indexToFile(1), 0);     // Rest note
        lastNote = 0;
    }

    //  updateLights  --  Update the shift register display lights

    updateLights() {
        integer i;

        for (i = 0; i <= 8; i++) {
            vector colour;

            if (Colour) {
                integer bit = shiftReg & (1 << i);
                if (bit != 0) {
                    bit = 1;
                }
                integer nhist;
                shiftHist = llListReplaceList(shiftHist,
                    [ (nhist = ((llList2Integer(shiftHist, i) << 1) | bit) & 7) ], i, i);
                float r = 0.078;
                float g = 0.078;
                float b = 0.078;
                if ((nhist & 1) != 0) {
                    r = 1;
                }
                if ((nhist & 2) != 0) {
                    g = 1;
                }
                if ((nhist & 4) != 0) {
                    b = 1;
                }
                colour = <r, g, b>;

            } else {
                if (shiftReg & (1 << i)) {
                    colour = <1, 0, 0>;
                } else {
                    colour = <0.5, 0, 0>;
                }
            }

            llSetLinkPrimitiveParamsFast(llList2Integer(lights, i),
                [ PRIM_COLOR, ALL_SIDES, colour, 1 ]);
        }
    }

    //  updateButtons  --  Update buttons from current tuneSelect

    updateButtons() {
        integer i;

        for (i = 0; i < 4; i++) {
            integer b = 1 << i;
            vector colour = <0.5, 0.5, 0.5>;
            if ((tuneSelect & b) != 0) {
                colour = <0.5, 0.75, 0.5>;
            }
            llSetLinkPrimitiveParamsFast(llList2Integer(buttons, i),
                [ PRIM_COLOR, 2, colour, 1 ]);  // 2 selects face toward the user
        }
    }

    default {

        on_rez(integer start_param) {
            llResetScript();                // Force script reset
        }

        state_entry() {

            //  Save indices of linked child prims

            integer i;

            //  Build list of light link numbers
            for (i = 0; i <= 8; i++) {
                integer l = findLinkNumber("B" + (string) i);
                lights += l;
            }

            //  Build list of button link numbers
            for (i = 0; i < 4; i++) {
                integer l = findLinkNumber("L" + (string) (1 << i));
                buttons += l;
            }

            //  Start listening on the command chat channel
            commandH = llListen(commandChannel, "", NULL_KEY, "");
            tawk("Chat /" + (string) commandChannel + " help for instructions.");

            shiftReg = rand31();        // Randomise the shift register
            lastNote = 0;

            updateButtons();

/*
            //  Preload the sounds

            for (i = 1; i <= 15; i++) {
                llPreloadSound(indexToFile(i));
            }
tawk("Sounds loaded.");
*/
        }

        /*  The listen event handler processes messages from
            our chat control channel.  */

        listen(integer channel, string name, key id, string message) {
            processCommand(id, message);
        }

        //  On touch, toggle play/stop mode

        touch_start(integer total_number) {
            integer LM_PANEL = 1;               // Link number of front panel
            vector where = llDetectedTouchPos(0);
            vector msize = llList2Vector(llGetLinkPrimitiveParams(LM_PANEL,
                [ PRIM_SIZE ]), 0);
            vector mpos = llList2Vector(llGetLinkPrimitiveParams(LM_PANEL,
                [ PRIM_POSITION ]), 0);
            rotation mrot = llList2Rot(llGetLinkPrimitiveParams(LM_PANEL,
                [ PRIM_ROTATION ]), 0);
            /*  Get location of touch relative to front panel,
                as fraction of panel dimensions.  */
            vector lwhere = (where - mpos) / mrot;

            if ((lwhere.z / msize.z) <= -0.38) {
                //  Touch in control panel.  Find quarter.
                integer qtr = (integer) (((lwhere.y / msize.y) + 0.5) * 4);
                tuneSelect = tuneSelect ^ (8 >> qtr);
                updateButtons();
            } else {
                running = !running;

                if (running) {
                    llSetTimerEvent(Tempo);
                } else {
                    squelch();
                    llSetTimerEvent(0);
                }
            }
        }

        //  When timer ticks, update shift register, play note, paint lights

        timer() {
            integer note = shiftR();
            note = note ^ tuneSelect;
            if (note > 0) {
                if (lastNote != note) {
                    llPlaySound(indexToFile(note), Volume);
                }
                lastNote = note;
            } else {
                squelch();
            }

            updateLights();
        }
    }
