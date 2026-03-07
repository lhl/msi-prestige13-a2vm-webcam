/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20250404 (64-bit version)
 * Copyright (c) 2000 - 2025 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of ssdt22.dat
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x00000832 (2098)
 *     Revision         0x02
 *     Checksum         0x06
 *     OEM ID           "INTEL"
 *     OEM Table ID     "xh_lnl_m"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20210930 (539035952)
 */
DefinitionBlock ("", "SSDT", 2, "INTEL", "xh_lnl_m", 0x00000000)
{
    External (_SB_.PC00.TXHC.RHUB.SS01, DeviceObj)
    External (_SB_.PC00.TXHC.RHUB.SS02, DeviceObj)
    External (_SB_.PC00.TXHC.RHUB.SS03, DeviceObj)
    External (_SB_.PC00.XHCI, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS01, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS02, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS03, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS04, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS05, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.HS06, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS01, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS02, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS03, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS04, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS05, DeviceObj)
    External (_SB_.PC00.XHCI.RHUB.SS06, DeviceObj)
    External (_SB_.UBTC.RUCC, MethodObj)    // 3 Arguments
    External (PU2C, UnknownObj)
    External (PU3C, UnknownObj)
    External (SXI1, IntObj)
    External (SXI2, IntObj)
    External (SXP1, IntObj)
    External (SXP2, IntObj)
    External (TP1C, IntObj)
    External (TP2C, IntObj)
    External (TP3C, IntObj)
    External (VTCM, IntObj)

    Method (GPLD, 2, Serialized)
    {
        Name (PCKG, Package (0x01)
        {
            Buffer (0x14){}
        })
        CreateField (DerefOf (PCKG [Zero]), Zero, 0x07, REV)
        REV = 0x02
        CreateField (DerefOf (PCKG [Zero]), 0x07, One, RGB)
        RGB = One
        CreateField (DerefOf (PCKG [Zero]), 0x40, One, VISI)
        VISI = Arg0
        CreateField (DerefOf (PCKG [Zero]), 0x57, 0x08, GPOS)
        GPOS = Arg1
        CreateField (DerefOf (PCKG [Zero]), 0x80, 0x10, VOFF)
        VOFF = 0xFFFF
        CreateField (DerefOf (PCKG [Zero]), 0x90, 0x10, HOFF)
        HOFF = 0xFFFF
        Return (PCKG) /* \GPLD.PCKG */
    }

    Method (GUPC, 2, Serialized)
    {
        Name (PCKG, Package (0x04)
        {
            0xFF, 
            0xFF, 
            Zero, 
            Zero
        })
        PCKG [Zero] = Arg0
        PCKG [One] = Arg1
        Return (PCKG) /* \GUPC.PCKG */
    }

    Scope (\_SB.PC00.TXHC.RHUB.SS01)
    {
        Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
        {
            Return (\_SB.UBTC.RUCC (One, One, TP1C))
        }

        Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
        {
            Return (\_SB.UBTC.RUCC (One, 0x02, Zero))
        }
    }

    Scope (\_SB.PC00.TXHC.RHUB.SS02)
    {
        Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
        {
            Return (\_SB.UBTC.RUCC (0x02, One, TP2C))
        }

        Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
        {
            Return (\_SB.UBTC.RUCC (0x02, 0x02, Zero))
        }
    }

    Scope (_SB.PC00.TXHC.RHUB.SS03)
    {
        Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
        {
            Return (GUPC (Zero, 0xFF))
        }

        Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
        {
            Return (GPLD (Zero, Zero))
        }
    }

    If ((One <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS01)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                Return (\_SB.UBTC.RUCC (One, One, TP1C))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                Return (\_SB.UBTC.RUCC (One, 0x02, Zero))
            }
        }
    }

    If ((0x02 <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS02)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                Return (\_SB.UBTC.RUCC (0x02, One, TP2C))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                Return (\_SB.UBTC.RUCC (0x02, 0x02, Zero))
            }
        }
    }

    If ((0x03 <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS03)
        {
            If ((CondRefOf (VTCM) && (VTCM == One)))
            {
                If (((SXP1 == 0x03) || (SXP2 == 0x03)))
                {
                    Device (CIR)
                    {
                        Method (_ADR, 0, NotSerialized)  // _ADR: Address
                        {
                            If ((SXP1 == 0x03))
                            {
                                Return ((SXP1 + SXI1))
                            }
                            Else
                            {
                                Return ((SXP2 + SXI2))
                            }
                        }
                    }
                }
            }

            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x03) || (SXP2 == 0x03)))
                    {
                        Return (Package (0x04)
                        {
                            0xFF, 
                            0xFF, 
                            Zero, 
                            Zero
                        })
                    }
                }

                Return (GUPC (Zero, 0xFF))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x03) || (SXP2 == 0x03)))
                    {
                        Return (Package (0x01)
                        {
                            Buffer (0x14)
                            {
                                /* 0000 */  0x82, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                                /* 0008 */  0x00, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                                /* 0010 */  0xFF, 0xFF, 0xFF, 0xFF                           // ....
                            }
                        })
                    }
                }

                Return (GPLD (Zero, 0x03))
            }
        }
    }

    If ((0x04 <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS04)
        {
            If ((CondRefOf (VTCM) && (VTCM == One)))
            {
                If (((SXP1 == 0x04) || (SXP2 == 0x04)))
                {
                    Device (CIR)
                    {
                        Method (_ADR, 0, NotSerialized)  // _ADR: Address
                        {
                            If ((SXP1 == 0x04))
                            {
                                Return ((SXP1 + SXI1))
                            }
                            Else
                            {
                                Return ((SXP2 + SXI2))
                            }
                        }
                    }
                }
            }

            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x04) || (SXP2 == 0x04)))
                    {
                        Return (Package (0x04)
                        {
                            0xFF, 
                            0xFF, 
                            Zero, 
                            Zero
                        })
                    }
                }

                Return (GUPC (Zero, 0xFF))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x04) || (SXP2 == 0x04)))
                    {
                        Return (Package (0x01)
                        {
                            Buffer (0x14)
                            {
                                /* 0000 */  0x82, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                                /* 0008 */  0x00, 0x80, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,  // ........
                                /* 0010 */  0xFF, 0xFF, 0xFF, 0xFF                           // ....
                            }
                        })
                    }
                }

                Return (GPLD (Zero, 0x04))
            }
        }
    }

    If ((0x05 <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS05)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                Return (GUPC (One, Zero))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                Return (GPLD (One, 0x05))
            }
        }
    }

    If ((0x06 <= PU2C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.HS06)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                Return (GUPC (Zero, 0xFF))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                Return (GPLD (Zero, 0x06))
            }
        }
    }

    If ((One <= PU3C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.SS01)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x03) || (SXP2 == 0x03)))
                    {
                        Return (GUPC (Zero, 0xFF))
                    }
                }

                Return (GUPC (One, Zero))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x03) || (SXP2 == 0x03)))
                    {
                        Return (GPLD (Zero, 0x03))
                    }
                }

                Return (GPLD (One, 0x05))
            }
        }
    }

    If ((0x02 <= PU3C))
    {
        Scope (\_SB.PC00.XHCI.RHUB.SS02)
        {
            Method (_UPC, 0, NotSerialized)  // _UPC: USB Port Capabilities
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x04) || (SXP2 == 0x04)))
                    {
                        Return (GUPC (Zero, 0xFF))
                    }
                }

                Return (GUPC (Zero, 0xFF))
            }

            Method (_PLD, 0, NotSerialized)  // _PLD: Physical Location of Device
            {
                If ((CondRefOf (VTCM) && (VTCM == One)))
                {
                    If (((SXP1 == 0x04) || (SXP2 == 0x04)))
                    {
                        Return (GPLD (Zero, 0x04))
                    }
                }

                Return (GPLD (Zero, Zero))
            }
        }
    }
}

