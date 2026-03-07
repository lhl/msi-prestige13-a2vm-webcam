/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20250404 (64-bit version)
 * Copyright (c) 2000 - 2025 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of ssdt27.dat
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x00000C8C (3212)
 *     Revision         0x02
 *     Checksum         0x70
 *     OEM ID           "INTEL "
 *     OEM Table ID     "PDatTabl"
 *     OEM Revision     0x00001000 (4096)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20210930 (539035952)
 */
DefinitionBlock ("", "SSDT", 2, "INTEL ", "PDatTabl", 0x00001000)
{
    External (_SB_.IETM.CHRG, DeviceObj)
    External (_SB_.IETM.SEN2, DeviceObj)
    External (_SB_.IETM.SEN3, DeviceObj)
    External (_SB_.IETM.SEN4, DeviceObj)
    External (_SB_.IETM.SEN5, DeviceObj)
    External (_SB_.IETM.TFN1, DeviceObj)
    External (_SB_.IETM.TPWR, DeviceObj)
    External (_SB_.PC00.TCPU, DeviceObj)
    External (BREV, IntObj)
    External (PLID, IntObj)

    Scope (\_SB)
    {
        Device (PLDT)
        {
            Name (_HID, EisaId ("PNP0A05") /* Generic Container Device */)  // _HID: Hardware ID
            Name (_UID, 0x06)  // _UID: Unique ID
            Name (_STR, Unicode ("Platform Data"))  // _STR: Description String
            Method (_STA, 0, NotSerialized)  // _STA: Status
            {
                Return (0x0F)
            }

            Method (GHID, 1, Serialized)
            {
                If ((Arg0 == "IETM"))
                {
                    Return ("INTC1068")
                }

                If ((Arg0 == "SEN1"))
                {
                    Return ("INTC1069")
                }

                If ((Arg0 == "SEN2"))
                {
                    Return ("INTC1069")
                }

                If ((Arg0 == "SEN3"))
                {
                    Return ("INTC1069")
                }

                If ((Arg0 == "SEN4"))
                {
                    Return ("INTC1069")
                }

                If ((Arg0 == "SEN5"))
                {
                    Return ("INTC1069")
                }

                If ((Arg0 == "TPCH"))
                {
                    Return ("INTC106D")
                }

                If ((Arg0 == "TFN1"))
                {
                    Return ("INTC106A")
                }

                If ((Arg0 == "TFN2"))
                {
                    Return ("INTC106A")
                }

                If ((Arg0 == "TFN3"))
                {
                    Return ("INTC106A")
                }

                If ((Arg0 == "TPWR"))
                {
                    Return ("INTC106C")
                }

                If ((Arg0 == "1"))
                {
                    Return ("INTC106D")
                }

                If ((Arg0 == "CHRG"))
                {
                    Return ("INTC1069")
                }

                Return ("XXXX9999")
            }

            Method (GDDV, 0, Serialized)
            {
                Return (Package (0x01)
                {
                    Buffer (0x0490)
                    {
                        /* 0000 */  0xE5, 0x1F, 0x94, 0x00, 0x00, 0x00, 0x00, 0x02,  // ........
                        /* 0008 */  0x00, 0x00, 0x00, 0x40, 0x67, 0x64, 0x64, 0x76,  // ...@gddv
                        /* 0010 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0018 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0020 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0028 */  0x00, 0x00, 0x00, 0x00, 0x4F, 0x45, 0x4D, 0x20,  // ....OEM 
                        /* 0030 */  0x45, 0x78, 0x70, 0x6F, 0x72, 0x74, 0x65, 0x64,  // Exported
                        /* 0038 */  0x20, 0x44, 0x61, 0x74, 0x61, 0x56, 0x61, 0x75,  //  DataVau
                        /* 0040 */  0x6C, 0x74, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // lt......
                        /* 0048 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0050 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0058 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0060 */  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                        /* 0068 */  0x00, 0x00, 0x00, 0x00, 0x15, 0x51, 0xA9, 0x7A,  // .....Q.z
                        /* 0070 */  0x3B, 0x6B, 0xD0, 0x3D, 0x6C, 0x99, 0x53, 0x39,  // ;k.=l.S9
                        /* 0078 */  0x21, 0xE9, 0x06, 0x53, 0x5F, 0x8F, 0x49, 0x62,  // !..S_.Ib
                        /* 0080 */  0xC4, 0xA1, 0x76, 0x14, 0xAB, 0x85, 0x26, 0x45,  // ..v...&E
                        /* 0088 */  0x6A, 0x72, 0x65, 0xB7, 0xFC, 0x03, 0x00, 0x00,  // jre.....
                        /* 0090 */  0x52, 0x45, 0x50, 0x4F, 0x5D, 0x00, 0x00, 0x00,  // REPO]...
                        /* 0098 */  0x01, 0x48, 0x2E, 0x00, 0x00, 0x00, 0x00, 0x00,  // .H......
                        /* 00A0 */  0x00, 0x00, 0x72, 0x87, 0xCD, 0xFF, 0x6D, 0x24,  // ..r...m$
                        /* 00A8 */  0x47, 0xDB, 0x3D, 0x24, 0x92, 0xB4, 0x16, 0x6F,  // G.=$...o
                        /* 00B0 */  0x45, 0xD8, 0xC3, 0xF5, 0x66, 0x14, 0x9F, 0x22,  // E...f.."
                        /* 00B8 */  0xD7, 0xF7, 0xDE, 0x67, 0x90, 0x9A, 0xA2, 0x0D,  // ...g....
                        /* 00C0 */  0x39, 0x25, 0xAD, 0xC3, 0x1A, 0xAD, 0x52, 0x0B,  // 9%....R.
                        /* 00C8 */  0x75, 0x38, 0xE1, 0xA4, 0x14, 0x41, 0x71, 0xFE,  // u8...Aq.
                        /* 00D0 */  0x36, 0xAE, 0xF1, 0x69, 0x93, 0x49, 0xB6, 0xF2,  // 6..i.I..
                        /* 00D8 */  0x43, 0x03, 0x00, 0xBE, 0x1D, 0x56, 0xA7, 0x03,  // C....V..
                        /* 00E0 */  0x99, 0xE2, 0x8A, 0x7F, 0x2B, 0x60, 0x0E, 0xF2,  // ....+`..
                        /* 00E8 */  0x08, 0x7A, 0xEC, 0x0B, 0x14, 0x73, 0xC2, 0x77,  // .z...s.w
                        /* 00F0 */  0xBB, 0x8A, 0x17, 0x2D, 0xFC, 0x01, 0x04, 0xCF,  // ...-....
                        /* 00F8 */  0x96, 0xFC, 0x1A, 0x94, 0x79, 0x52, 0x11, 0xAC,  // ....yR..
                        /* 0100 */  0x09, 0x45, 0x5A, 0x0C, 0xEF, 0x72, 0xB7, 0x15,  // .EZ..r..
                        /* 0108 */  0xB7, 0x6D, 0x35, 0x89, 0xA4, 0x9A, 0x55, 0xDC,  // .m5...U.
                        /* 0110 */  0x64, 0x4D, 0x5D, 0x2C, 0x7B, 0x06, 0x89, 0xF2,  // dM],{...
                        /* 0118 */  0xBD, 0x9E, 0x31, 0xE9, 0xAB, 0xB5, 0x37, 0x5B,  // ..1...7[
                        /* 0120 */  0xCC, 0x02, 0xAD, 0xED, 0x6F, 0x5D, 0x65, 0x16,  // ....o]e.
                        /* 0128 */  0x8C, 0x5C, 0x44, 0x0D, 0x46, 0x02, 0x2C, 0xA1,  // .\D.F.,.
                        /* 0130 */  0x35, 0x81, 0x9D, 0xE3, 0xA6, 0x58, 0xC2, 0xDE,  // 5....X..
                        /* 0138 */  0x79, 0x50, 0xE9, 0x22, 0xFF, 0xBC, 0x5E, 0x2A,  // yP."..^*
                        /* 0140 */  0xBE, 0xC2, 0x0C, 0x7E, 0x81, 0xEA, 0x8A, 0x63,  // ...~...c
                        /* 0148 */  0xC6, 0xC5, 0xCA, 0x1E, 0x9B, 0x89, 0x53, 0x98,  // ......S.
                        /* 0150 */  0xFE, 0x81, 0x0B, 0xF8, 0x62, 0xF5, 0x0C, 0x56,  // ....b..V
                        /* 0158 */  0x58, 0x65, 0x7E, 0xBF, 0x40, 0x8D, 0x92, 0xE5,  // Xe~.@...
                        /* 0160 */  0x48, 0xB0, 0xB8, 0xF1, 0xAA, 0x59, 0x65, 0x2B,  // H....Ye+
                        /* 0168 */  0xF2, 0xE0, 0xC4, 0x23, 0x00, 0xE0, 0x74, 0x1E,  // ...#..t.
                        /* 0170 */  0x9C, 0xF6, 0x72, 0xBD, 0x78, 0x93, 0x80, 0x95,  // ..r.x...
                        /* 0178 */  0xFE, 0xD7, 0x6F, 0x0F, 0x66, 0x34, 0x3A, 0x88,  // ..o.f4:.
                        /* 0180 */  0x73, 0xF2, 0x18, 0x65, 0x05, 0xC6, 0x7E, 0xEC,  // s..e..~.
                        /* 0188 */  0xB0, 0xDD, 0x3C, 0x32, 0x53, 0x1D, 0xCB, 0x39,  // ..<2S..9
                        /* 0190 */  0x44, 0x0F, 0x8D, 0xA8, 0xB6, 0x2D, 0x2B, 0x70,  // D....-+p
                        /* 0198 */  0x8A, 0x2B, 0xB3, 0x67, 0xC9, 0x6A, 0xD9, 0x2B,  // .+.g.j.+
                        /* 01A0 */  0xC7, 0x56, 0xC8, 0x5B, 0x82, 0x8B, 0xBE, 0x26,  // .V.[...&
                        /* 01A8 */  0xF3, 0xFE, 0x00, 0x50, 0xAA, 0xEC, 0xC4, 0x12,  // ...P....
                        /* 01B0 */  0xE4, 0xCB, 0xAB, 0xFF, 0xF7, 0x1B, 0xE4, 0x34,  // .......4
                        /* 01B8 */  0x59, 0xE4, 0xEF, 0xD1, 0xB3, 0x4F, 0x90, 0x9C,  // Y....O..
                        /* 01C0 */  0x8A, 0xFE, 0x88, 0xC9, 0xED, 0x02, 0x5D, 0xB2,  // ......].
                        /* 01C8 */  0xBF, 0xC6, 0x85, 0x4B, 0x99, 0x34, 0x5A, 0x79,  // ...K.4Zy
                        /* 01D0 */  0x13, 0xA6, 0x9D, 0xE2, 0x43, 0x74, 0xC7, 0x4C,  // ....Ct.L
                        /* 01D8 */  0x35, 0x00, 0xBA, 0x8F, 0x60, 0xE8, 0x5B, 0xA8,  // 5...`.[.
                        /* 01E0 */  0x4D, 0x9A, 0x7B, 0x07, 0xD7, 0x56, 0x43, 0x76,  // M.{..VCv
                        /* 01E8 */  0xE7, 0xDB, 0xF3, 0x86, 0x02, 0x99, 0x22, 0x79,  // ......"y
                        /* 01F0 */  0x4C, 0x44, 0x24, 0xA8, 0x09, 0x52, 0xCD, 0x97,  // LD$..R..
                        /* 01F8 */  0x76, 0x9B, 0xE0, 0xB3, 0xDE, 0x6D, 0x02, 0x41,  // v....m.A
                        /* 0200 */  0xC6, 0x62, 0x8A, 0x78, 0xA5, 0x74, 0x64, 0x34,  // .b.x.td4
                        /* 0208 */  0x7A, 0x98, 0x59, 0xF4, 0x88, 0x7D, 0x87, 0x78,  // z.Y..}.x
                        /* 0210 */  0x36, 0x45, 0xB9, 0xDB, 0xDC, 0x64, 0x28, 0x4D,  // 6E...d(M
                        /* 0218 */  0x9B, 0xAD, 0xAD, 0xC1, 0xAB, 0x2E, 0x19, 0x1E,  // ........
                        /* 0220 */  0x62, 0xE6, 0xB3, 0x91, 0xA9, 0x8A, 0xDA, 0x32,  // b......2
                        /* 0228 */  0x4F, 0xD7, 0x38, 0x08, 0x6C, 0x77, 0xD8, 0x9A,  // O.8.lw..
                        /* 0230 */  0xB6, 0xCF, 0x3B, 0x3A, 0xEE, 0xE1, 0x0F, 0x8E,  // ..;:....
                        /* 0238 */  0x4E, 0x2C, 0x7B, 0x26, 0x5D, 0x4C, 0x6E, 0x5F,  // N,{&]Ln_
                        /* 0240 */  0x93, 0x04, 0x55, 0xC3, 0x35, 0x9A, 0x26, 0xCE,  // ..U.5.&.
                        /* 0248 */  0x9D, 0xF2, 0xC9, 0x2B, 0xA7, 0xCA, 0x55, 0x43,  // ...+..UC
                        /* 0250 */  0x2C, 0x0C, 0x9C, 0x98, 0x57, 0x7C, 0xD3, 0xB7,  // ,...W|..
                        /* 0258 */  0xAB, 0x3B, 0xEE, 0xE4, 0xB1, 0xA6, 0x9D, 0x45,  // .;.....E
                        /* 0260 */  0xFE, 0x62, 0x11, 0xB0, 0x3D, 0xC3, 0x26, 0x63,  // .b..=.&c
                        /* 0268 */  0xE9, 0x36, 0xA4, 0x28, 0x64, 0xA8, 0x5D, 0xEC,  // .6.(d.].
                        /* 0270 */  0xDD, 0x87, 0x7D, 0x85, 0xEA, 0x92, 0xAF, 0xE8,  // ..}.....
                        /* 0278 */  0x0D, 0xA5, 0x26, 0xB2, 0xE8, 0x69, 0x6F, 0xD1,  // ..&..io.
                        /* 0280 */  0xB1, 0x44, 0x2D, 0xE0, 0xFD, 0x6F, 0x7D, 0x8B,  // .D-..o}.
                        /* 0288 */  0x90, 0x0A, 0xCE, 0xDC, 0xDF, 0x81, 0xBB, 0x2C,  // .......,
                        /* 0290 */  0x89, 0xEA, 0xEB, 0x8C, 0x0C, 0xBF, 0xF8, 0x6B,  // .......k
                        /* 0298 */  0xFD, 0x66, 0xF2, 0x92, 0x41, 0x38, 0xF2, 0x7D,  // .f..A8.}
                        /* 02A0 */  0xAF, 0x67, 0xB6, 0x27, 0x56, 0x19, 0x52, 0xB4,  // .g.'V.R.
                        /* 02A8 */  0x30, 0xF3, 0xEE, 0x40, 0x5C, 0xB0, 0x63, 0xD0,  // 0..@\.c.
                        /* 02B0 */  0x29, 0xB1, 0xDF, 0x58, 0x28, 0xB8, 0xEF, 0x0D,  // )..X(...
                        /* 02B8 */  0x06, 0x6A, 0x0A, 0xFB, 0xD2, 0xDB, 0x76, 0x76,  // .j....vv
                        /* 02C0 */  0xAD, 0x1A, 0xDB, 0xC2, 0x1C, 0x88, 0x63, 0x91,  // ......c.
                        /* 02C8 */  0xB4, 0x95, 0x39, 0x1E, 0x44, 0x69, 0x46, 0xA1,  // ..9.DiF.
                        /* 02D0 */  0x05, 0x86, 0xBC, 0x2B, 0x77, 0xF2, 0x10, 0x99,  // ...+w...
                        /* 02D8 */  0xAB, 0x80, 0x59, 0x96, 0x9B, 0x3F, 0x93, 0x26,  // ..Y..?.&
                        /* 02E0 */  0xF6, 0x40, 0x04, 0x77, 0xE4, 0xE1, 0x13, 0x0D,  // .@.w....
                        /* 02E8 */  0x8B, 0xF3, 0xEE, 0x9A, 0xB7, 0xFA, 0xDA, 0x58,  // .......X
                        /* 02F0 */  0xA5, 0x8C, 0xE4, 0xD4, 0x88, 0x66, 0x10, 0x03,  // .....f..
                        /* 02F8 */  0x8A, 0x37, 0x09, 0xDD, 0xC2, 0x7D, 0x38, 0xE3,  // .7...}8.
                        /* 0300 */  0x72, 0xB2, 0x7E, 0xEB, 0x11, 0x51, 0x62, 0xBF,  // r.~..Qb.
                        /* 0308 */  0x22, 0x9F, 0x1D, 0xBF, 0x3C, 0x6D, 0xA3, 0x6E,  // "...<m.n
                        /* 0310 */  0xE4, 0xCD, 0xCD, 0xCB, 0x38, 0x14, 0x60, 0x4B,  // ....8.`K
                        /* 0318 */  0x5E, 0x75, 0x32, 0x4A, 0xE3, 0x69, 0x5F, 0x10,  // ^u2J.i_.
                        /* 0320 */  0x9B, 0x1F, 0xDC, 0xDB, 0x89, 0x84, 0x12, 0x85,  // ........
                        /* 0328 */  0x3E, 0x4D, 0xCC, 0x01, 0xB7, 0x89, 0xAB, 0x72,  // >M.....r
                        /* 0330 */  0xE4, 0x72, 0x15, 0x62, 0xFB, 0x6F, 0xD9, 0x93,  // .r.b.o..
                        /* 0338 */  0xD6, 0x04, 0xCA, 0x07, 0x65, 0x58, 0x49, 0x8E,  // ....eXI.
                        /* 0340 */  0xAF, 0x7E, 0x51, 0x52, 0xD6, 0xCB, 0x3E, 0xB4,  // .~QR..>.
                        /* 0348 */  0x39, 0x6B, 0x27, 0x59, 0x8F, 0xF1, 0x93, 0xF2,  // 9k'Y....
                        /* 0350 */  0x79, 0x4C, 0x9E, 0xF3, 0x1D, 0x3B, 0xC6, 0xB4,  // yL...;..
                        /* 0358 */  0xC2, 0x22, 0x5A, 0x88, 0x98, 0xA4, 0x3A, 0xC8,  // ."Z...:.
                        /* 0360 */  0x84, 0x65, 0x9B, 0x71, 0x64, 0x89, 0x05, 0xDB,  // .e.qd...
                        /* 0368 */  0xC3, 0x22, 0xFC, 0x4B, 0xE9, 0x24, 0xE1, 0x2F,  // .".K.$./
                        /* 0370 */  0x53, 0x7C, 0x5B, 0xCA, 0x7B, 0xFD, 0x1C, 0xC5,  // S|[.{...
                        /* 0378 */  0x2F, 0x9B, 0xAB, 0x74, 0x36, 0xDA, 0xA9, 0x13,  // /..t6...
                        /* 0380 */  0x10, 0xEC, 0xC0, 0x3A, 0xCF, 0x0F, 0x67, 0xD8,  // ...:..g.
                        /* 0388 */  0x1A, 0x32, 0x26, 0x86, 0x64, 0xB2, 0xC1, 0x91,  // .2&.d...
                        /* 0390 */  0x76, 0xD4, 0xBA, 0xF7, 0x2B, 0x33, 0x62, 0xD3,  // v...+3b.
                        /* 0398 */  0xBA, 0x1F, 0x50, 0x09, 0x1E, 0xFF, 0x7C, 0xE8,  // ..P...|.
                        /* 03A0 */  0x92, 0xE1, 0x47, 0x2E, 0x6D, 0x9D, 0x08, 0x1A,  // ..G.m...
                        /* 03A8 */  0x07, 0xB5, 0x40, 0xD0, 0x77, 0x21, 0x67, 0xAF,  // ..@.w!g.
                        /* 03B0 */  0x60, 0x15, 0x8B, 0x60, 0x0D, 0xCC, 0x5E, 0x1B,  // `..`..^.
                        /* 03B8 */  0x10, 0x3E, 0xFD, 0x4C, 0x24, 0x95, 0xB3, 0x67,  // .>.L$..g
                        /* 03C0 */  0x06, 0xCE, 0x41, 0x54, 0x3D, 0x89, 0x84, 0xD4,  // ..AT=...
                        /* 03C8 */  0x40, 0xFA, 0x79, 0x9A, 0x67, 0x62, 0x4B, 0x90,  // @.y.gbK.
                        /* 03D0 */  0xFA, 0x9E, 0xF6, 0xF1, 0x5F, 0x35, 0xCB, 0x18,  // ...._5..
                        /* 03D8 */  0x9B, 0x56, 0x35, 0x94, 0x96, 0x6D, 0xBA, 0x53,  // .V5..m.S
                        /* 03E0 */  0x4C, 0xDB, 0x62, 0x05, 0x3B, 0xAE, 0xB1, 0xBC,  // L.b.;...
                        /* 03E8 */  0x1D, 0x80, 0xB3, 0x73, 0x94, 0xA7, 0x0E, 0x14,  // ...s....
                        /* 03F0 */  0xFA, 0xEC, 0x79, 0x06, 0x88, 0xE9, 0x06, 0x03,  // ..y.....
                        /* 03F8 */  0xAC, 0x7D, 0x64, 0x7C, 0x56, 0x81, 0x9A, 0x3B,  // .}d|V..;
                        /* 0400 */  0x80, 0x17, 0x63, 0x97, 0x75, 0x53, 0x12, 0xB6,  // ..c.uS..
                        /* 0408 */  0x58, 0x10, 0x41, 0x0D, 0xCD, 0x94, 0x35, 0xEB,  // X.A...5.
                        /* 0410 */  0xA1, 0x06, 0x67, 0x87, 0x5E, 0x54, 0x1E, 0xBD,  // ..g.^T..
                        /* 0418 */  0xB6, 0xC8, 0x51, 0x83, 0x09, 0x48, 0x1E, 0x2B,  // ..Q..H.+
                        /* 0420 */  0x03, 0x83, 0x1A, 0x97, 0x13, 0x33, 0x09, 0xF9,  // .....3..
                        /* 0428 */  0xD4, 0x6F, 0xE9, 0x83, 0x75, 0x55, 0xD4, 0xCA,  // .o..uU..
                        /* 0430 */  0x7A, 0x11, 0x59, 0xFB, 0x60, 0xB4, 0x2E, 0x43,  // z.Y.`..C
                        /* 0438 */  0x54, 0xD4, 0x9A, 0x08, 0x8C, 0x64, 0x99, 0x0F,  // T....d..
                        /* 0440 */  0x3A, 0xFB, 0x3C, 0x59, 0xB9, 0x7C, 0x87, 0x8F,  // :.<Y.|..
                        /* 0448 */  0x3F, 0x65, 0x09, 0x32, 0x64, 0xDB, 0xF0, 0x26,  // ?e.2d..&
                        /* 0450 */  0x30, 0x98, 0xAA, 0x60, 0xC6, 0x21, 0x1F, 0x57,  // 0..`.!.W
                        /* 0458 */  0xD7, 0x56, 0x18, 0x95, 0xDD, 0xDB, 0xD9, 0x61,  // .V.....a
                        /* 0460 */  0x18, 0xA3, 0xC3, 0xDA, 0x29, 0xA1, 0xBF, 0xBD,  // ....)...
                        /* 0468 */  0xEF, 0xC4, 0x33, 0x5A, 0xAA, 0xAB, 0xD1, 0x2E,  // ..3Z....
                        /* 0470 */  0x95, 0x56, 0x6E, 0x36, 0x71, 0x13, 0xB7, 0x9C,  // .Vn6q...
                        /* 0478 */  0xAC, 0x50, 0x2B, 0x54, 0x5E, 0x47, 0xF9, 0x9A,  // .P+T^G..
                        /* 0480 */  0x5B, 0x41, 0x02, 0x3F, 0x37, 0xF1, 0xAF, 0x74,  // [A.?7..t
                        /* 0488 */  0x39, 0xE9, 0xD8, 0x62, 0x90, 0xA7, 0x3E, 0xE2   // 9..b..>.
                    }
                })
            }

            Method (FIDC, 1, Serialized)
            {
                Switch (ToInteger (Arg0))
                {
                    Case (Zero)
                    {
                        Return (One)
                    }
                    Case (One)
                    {
                        Return (0x02)
                    }
                    Case (0x02)
                    {
                        Return (0x04)
                    }
                    Default
                    {
                        Return (0xF0)
                    }

                }
            }

            Method (FPST, 1, Serialized)
            {
                Switch (ToInteger (Arg0))
                {
                    Case (Zero)
                    {
                        Return (FPS0) /* \_SB_.PLDT.FPS0 */
                    }
                    Default
                    {
                        Return (FPS0) /* \_SB_.PLDT.FPS0 */
                    }

                }
            }

            Name (FPS0, Package (0x0D)
            {
                Zero, 
                Package (0x05)
                {
                    0x64, 
                    0xFFFFFFFF, 
                    0x2EE0, 
                    0x01F4, 
                    0x1388
                }, 

                Package (0x05)
                {
                    0x5F, 
                    0xFFFFFFFF, 
                    0x2D50, 
                    0x01DB, 
                    0x128E
                }, 

                Package (0x05)
                {
                    0x5A, 
                    0xFFFFFFFF, 
                    0x2BC0, 
                    0x01C2, 
                    0x1194
                }, 

                Package (0x05)
                {
                    0x55, 
                    0xFFFFFFFF, 
                    0x2904, 
                    0x01A9, 
                    0x109A
                }, 

                Package (0x05)
                {
                    0x50, 
                    0xFFFFFFFF, 
                    0x2648, 
                    0x0190, 
                    0x0FA0
                }, 

                Package (0x05)
                {
                    0x46, 
                    0xFFFFFFFF, 
                    0x2454, 
                    0x015E, 
                    0x0DAC
                }, 

                Package (0x05)
                {
                    0x3C, 
                    0xFFFFFFFF, 
                    0x1CE8, 
                    0x012C, 
                    0x0BB8
                }, 

                Package (0x05)
                {
                    0x32, 
                    0xFFFFFFFF, 
                    0x189C, 
                    0xFA, 
                    0x09C4
                }, 

                Package (0x05)
                {
                    0x28, 
                    0xFFFFFFFF, 
                    0x13EC, 
                    0xC8, 
                    0x07D0
                }, 

                Package (0x05)
                {
                    0x1E, 
                    0xFFFFFFFF, 
                    0x0ED8, 
                    0x96, 
                    0x05DC
                }, 

                Package (0x05)
                {
                    0x19, 
                    0xFFFFFFFF, 
                    0x0C80, 
                    0x7D, 
                    0x04E2
                }, 

                Package (0x05)
                {
                    Zero, 
                    0xFFFFFFFF, 
                    Zero, 
                    Zero, 
                    Zero
                }
            })
            Name (ART1, Package (0x06)
            {
                Zero, 
                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.PC00.TCPU, 
                    0x64, 
                    0x50, 
                    0x3C, 
                    0x28, 
                    0x1E, 
                    0x14, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN2, 
                    0x64, 
                    0x50, 
                    0x3C, 
                    0x1E, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN3, 
                    0x64, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0x50, 
                    0x3C, 
                    0x1E, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN4, 
                    0x64, 
                    0x50, 
                    0x3C, 
                    0x1E, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN5, 
                    0x64, 
                    0x50, 
                    0x3C, 
                    0x1E, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }
            })
            Name (ART0, Package (0x06)
            {
                Zero, 
                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.PC00.TCPU, 
                    0x64, 
                    0x64, 
                    0x50, 
                    0x32, 
                    0x28, 
                    0x1E, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN2, 
                    0x64, 
                    0x50, 
                    0x32, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN3, 
                    0x64, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0x64, 
                    0x50, 
                    0x32, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN4, 
                    0x64, 
                    0x64, 
                    0x50, 
                    0x32, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }, 

                Package (0x0D)
                {
                    \_SB.IETM.TFN1, 
                    \_SB.IETM.SEN5, 
                    0x64, 
                    0x64, 
                    0x50, 
                    0x32, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF
                }
            })
            Name (TRT0, Package (0x02)
            {
                Package (0x08)
                {
                    \_SB.PC00.TCPU, 
                    \_SB.IETM.SEN2, 
                    0x28, 
                    0x64, 
                    Zero, 
                    Zero, 
                    Zero, 
                    Zero
                }, 

                Package (0x08)
                {
                    \_SB.IETM.CHRG, 
                    \_SB.IETM.SEN4, 
                    0x14, 
                    0xC8, 
                    Zero, 
                    Zero, 
                    Zero, 
                    Zero
                }
            })
            Method (PTRT, 0, NotSerialized)
            {
                Return (TRT0) /* \_SB_.PLDT.TRT0 */
            }

            Name (PSVT, Package (0x05)
            {
                0x02, 
                Package (0x0C)
                {
                    \_SB.IETM.CHRG, 
                    \_SB.IETM.SEN3, 
                    One, 
                    0xC8, 
                    0x0C6E, 
                    0x0E, 
                    0x000A0000, 
                    "MAX", 
                    One, 
                    0x0A, 
                    0x0A, 
                    Zero
                }, 

                Package (0x0C)
                {
                    \_SB.IETM.CHRG, 
                    \_SB.IETM.SEN3, 
                    One, 
                    0xC8, 
                    0x0CA0, 
                    0x0E, 
                    0x000A0000, 
                    One, 
                    One, 
                    0x0A, 
                    0x0A, 
                    Zero
                }, 

                Package (0x0C)
                {
                    \_SB.IETM.CHRG, 
                    \_SB.IETM.SEN3, 
                    One, 
                    0xC8, 
                    0x0CD2, 
                    0x0E, 
                    0x000A0000, 
                    0x02, 
                    One, 
                    0x0A, 
                    0x0A, 
                    Zero
                }, 

                Package (0x0C)
                {
                    \_SB.IETM.CHRG, 
                    \_SB.IETM.SEN3, 
                    One, 
                    0xC8, 
                    0x0D36, 
                    0x0E, 
                    0x000A0000, 
                    "MIN", 
                    One, 
                    0x0A, 
                    0x0A, 
                    Zero
                }
            })
        }
    }
}

