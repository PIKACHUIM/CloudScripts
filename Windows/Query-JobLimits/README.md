## Query-JobLimits.ps1

#### NAME
    Query-JobLimits.ps1
    
#### SYNOPSIS
    Queries the job limits from inside a process-isolated container
    
#### SYNTAX
    Query-JobLimits.ps1 [-LimitType <String>] [<CommonParameters>]
    
    
#### DESCRIPTION
    Queries the job limits from inside a process-isolated container
    
    Once the container platform has set a CPU or Memory limit, this utility
    can be used to query those limits and potentially pass them to processes
    or workloads inside the container.

#### PARAMETERS
    -LimitType [<String>]
        The limit type to query from within the container
        
        Required?                    True
        Position?                    named
        Default value                
        Accept pipeline input?       false
        Accept wildcard characters?  false

        Determines the type of limit to query.  The following values are supported:
        - JobMemoryLimit: Returns the job memory limit in bytes
        - PeakJobMemoryUsed: Returns the peak job memory used in bytes
        - CpuRateControl: Returns the CPU rate control, if enabled, which is generally a cycle count out of a total of
        10000        

#### NOTES
        Copyright (c) Microsoft Corporation.  All rights reserved.
        
        Use of this sample source code is subject to the terms of the Microsoft
        license agreement under which you licensed this sample source code. If
        you did not accept the terms of the license agreement, you are not
        authorized to use this sample source code. For the terms of the license,
        please see the license agreement between you and Microsoft or, if applicable,
        see the LICENSE.RTF on your install media or the root of your tools installation.
        THE SAMPLE SOURCE CODE IS PROVIDED "AS IS", WITH NO WARRANTIES.
    
#### Examples
    
    PS C:\>.\Query-JobLimits.ps1 -LimitType JobMemoryLimit

    PS C:\>.\Query-JobLimits.ps1 -LimitType PeakJobMemoryUsed

    PS C:\>.\Query-JobLimits.ps1 -LimitType CpuRateControl

#### Prerequisites
Requires PowerShell version 5.0
