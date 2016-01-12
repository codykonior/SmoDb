<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

Clear
Import-Module SmoDb -Force
$global:PerformanceRecord.Clear()
try {
    Get-SmoInformation . . Ops -Verbose
} catch {
    $_
} finally {
    $totalTime = [timespan] 0
    $global:PerformanceRecord.GetEnumerator() | %{
        New-Object PSObject -Property @{
            Name = $_.Key
            Time = $_.Value
        }

        if ($_.Key -ne "(Properties)") {
            $totalTime += $_.Value
        }
    } | Sort Time -Descending | Select -First 20
    "Total: $totalTime"
}

# List table counts for an entry
Select 'Select ''' + t.name + ''', Count(*) From [smo].[' + t.name + '] Where [ServerName] = ''.'' Union'
From sys.tables t 
Where t.schema_id = schema_id('smo')
And t.name <> 'Server'

# Before property changes
Time                                                                                                             Name                                                                                                           
----                                                                                                             ----                                                                                                           
00:03:44.3505009                                                                                                 (Properties)                                                                                                   
00:02:30.7703572                                                                                                 (Performance Exclude)                                                                                          
00:00:40.1752434                                                                                                 Server/Database/User                                                                                           
00:00:38.3434462                                                                                                 Server/Database                                                                                                
00:00:34.1532836                                                                                                 Server/JobServer/Job                                                                                           
00:00:27.9140960                                                                                                 Server/Database/Role                                                                                           
00:00:14.8561602                                                                                                 Server/JobServer/Job/Step                                                                                      
00:00:08.7475801                                                                                                 Server/Database/FileGroup/File                                                                                 
00:00:08.4006632                                                                                                 Server/Login                                                                                                   
00:00:07.9526840                                                                                                 (Primary Key)                                                                                                  
00:00:06.2613902                                                                                                 Server/Configuration                                                                                           
00:00:06.1923840                                                                                                 Server/Database/LogFile                                                                                        
00:00:05.0444243                                                                                                 Server/Database/User/DefaultLanguage                                                                           
00:00:04.1152959                                                                                                 Server/JobServer/Schedule                                                                                      
00:00:03.4534178                                                                                                 Server/Database/FileGroup                                                                                      
00:00:03.3072249                                                                                                 Server/JobServer/Job/Schedule                                                                                  
00:00:02.5111564                                                                                                 Server                                                                                                         
00:00:02.2771550                                                                                                 Server/JobServer/Alert                                                                                         
00:00:01.3910679                                                                                                 Server/JobServer/JobCategory                                                                                   
00:00:01.3640968                                                                                                 Server/Setting/OleDbProviderSetting                                                                            
Total: 00:06:25.2358860



#>

function ConvertFrom-Smo {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,
        [System.Data.DataSet] $OutputObject,
        [int] $Depth = 0,
        # If there's no Urn property on the object we received, these "prior" properties are used to construct a path for 
        # a) checking against exclusions and indirectly 
        # b) the table name
        [string] $ParentPath,
        [string] $ParentPropertyName,
        $ParentPrimaryKeyColumns,
        $MaxDepth = 10
    )

    if ($OutputObject -eq $null) {
        $OutputObject = New-Object System.Data.DataSet
        $OutputObject.EnforceConstraints = $false
    }

    $Depth++
    $tab = "`t" * $Depth

    # Do a depth check. If this triggered it would mean we did something really wrong because everything should be
    # accessible within the depth I've selected.
    if ($Depth -gt $maxDepth) {
        Write-Error "$($tab)Max depth exceeded, this shouldn't have happened..."
    }

    # Work out a "path". This is something like /Server/Database/User. We may get to some type which doesn't have
    # its own Urn so in those cases we can fall back to the parent path plus property name.
    if (!$InputObject.psobject.Properties["Urn"]) {
        if ($ParentPath -and $ParentPropertyName) {
            $path = "$path/$ParentPropertyName"
            Write-Verbose "$($tab)Working on prior $path"
        } else {
            Write-Error "$($tab)No Urn, and no parent details, this shouldn't have happened"
        }
    } else {
        $urn = $InputObject.Urn
        $path = $urn.XPathExpression.ExpressionSkeleton
        Write-Verbose "$($tab)Working on $urn, the skeleton path is $path"
    }

    # These are table renames for conflicts and readability. I don't think it will work if you renamed 
    # one that has a foreign key dependency on it though. If you really wanted to do this you'd need
    # to work out how to make sub tables pick up this name; it gets extracted from the Urn which is why
    # it wouldn't work. Unless we switched that to use the path instead, and overwrote the path; here
    # and on the sub tables. I don't do that because splitting on the path breaks easily because it's
    # based on / which can show in lots of properties. The XPath doesn't have this issue. But we could
    # convert the $path variable to an array instead and then join it for comparisons.
    #
    # On second thoughts, the past primary key is fine. The new foreign key is fine. The foreign key
    # name is fine (it gets the name from the foreign key table). All that would be wrong is the name
    # of the new key for the foreign key because it's based on the XPath not on the past table name.
    # That could be fixed easily...
    #
    # These only rename TABLES, not PROPERTIES.
    $performancePath = Get-Date
    switch ($path) {
        # Rename for readability
        "Server/Mail/ConfigurationValue" {
            $tableName = "MailConfigurationValue"
            break
        }

        # Rename for readability
        "Server/UserOption" {
            $tableName = "ServerUserOption"
            break
        }

        # Schedule = Server/JobServer/Job/SharedSchedule
        "Server/JobServer/Job/Schedule" {
            $tableName = "JobSchedule"
            break
        }
        
        # Login = Server/Login 
        "Server/LinkedServer/Login" {
            $tableName = "LinkedServerLogin" # Server/Login goes under just Login
            break
        }

        # Don't use DefaultLanguage
        "Server/Database/DefaultLanguage" {
            $tableName = "DatabaseDefaultLanguage"
            break
        }
        "Server/Database/User/DefaultLanguage" {
            $tableName = "UserDefaultLanguage"
            break
        }
        
        # Don't use ServiceBroker
        "Server/Database/ServiceBroker" {
            $tableName = "DatabaseServiceBroker"
            break
        }
        "Server/Endpoint/ServiceBroker" {
            $tableName = "EndpointServiceBroker"
            break
        }                

        # Don't use Role
        "Server/Role" {
            $tableName = "ServerRole"
            break
        }
        "Server/Database/Role" {
            $tableName = "DatabaseRole"
            break
        }

        # Cpus = Server/AffinityInfo/Cpus
        "Server/AffinityInfo/NumaNodes/Cpus" {
            $tableName = "NumaNodesCpus"
            break
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/Schedulers/Cpu" {
            $tableName = "ResourcePoolCpus" # Not a typo, a standardization
            break
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes/Cpus" {
            $tableName = "ResourcePoolNumaNodesCpus"
            break
        }

        # NumaNodes = Server/AffinityInfo/NumaNodes
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes" {
            $tableName = "ResourcePoolNumaNodes"
            break
        }

        # Don't use IPAddress
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress" {
            $tableName = "ServerProtocolIPAddress"
            break
        }
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress/IPAddress" {
            $tableName = "ServerProtocolIPAddressDetail"
            break
        }

        default {
            # Configuration entries all follow the same pattern. We flatten them into one table.
            if ($path -like "Server/Configuration/*") {
                $tableName = "Configuration" 
            } else {
                $tableName = $path -split "/" | Select -Last 1
            }
        }
    }           
    "(Path Switch)" | Add-PerformanceRecord $performancePath

    # We can pull out the existing table or create a new one
    if ($OutputObject.Tables[$tableName]) {
        Write-Verbose "$($tab)Retrieving table $tableName"
        $table = $OutputObject.Tables[$tableName]
    } else {
        Write-Verbose "$($tab)Adding table $tableName"
        $table = $OutputObject.Tables.Add($tableName)
    }

    # Create a row but this isn't added to the table until all properties (and sub properties) have been processed on the row.
    # But the row must be created BEFORE we calculate primary keys, so we can add the values for each key item.
    $row = $table.NewRow()

    # We need to populate primary keys (and add the columns if necessary)
    Write-Verbose "$($tab)Preparing primary keys"
    $performancePrimaryKey = Get-Date
    $primaryKeyColumns = @()
    $foreignKeyColumns = @()

    # Primary key constraints are only made on the Urn, even if it's not the most current one. We apply fixups later.
    for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
        $key = $urn.XPathExpression.Item($i)

        # Iterate through each part of the URN; e.g. the Server part, the Database part, the User part.
        foreach ($keyProperty in $key.FixedProperties.GetEnumerator()) {            
            if ($i -eq ($urn.XPathExpression.Length - 1) -and $InputObject.psobject.Properties["Urn"]) {
                # If we are on the last part of the Urn, and the current row has a Urn, we use the proper name
                # (because this last name is the one that will be used on the current row as a property already)
                $keyPropertyName = $keyProperty.Name
            } else {
                # Otherwise we prefix names with the parent path name. We do this so that we don't get collisions
                # on things like Name; instead renaming them to ServerName, DatabaseName, etc, in the current row.
                # Also, if we were on the last step, but there is no Urn, then it means we still need to do this;
                # as the current row will be using a different current property name already, it's just not part
                # of the key yet (as far as we know, it will be "fixed" by adding it manually a bit later).

                $parentColumn = $ParentPrimaryKeyColumns[$primaryKeyColumns.Count]
                if (($ParentPrimaryKeyColumns[0].Table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint] } | Select -ExpandProperty Columns) -contains $parentColumn) {
                    $keyPropertyName = $parentColumn.ColumnName
                } else {
                    $keyPropertyName = "$($ParentPrimaryKeyColumns[0].Table.TableName)$($parentColumn.ColumnName)"
                }
            }
            # Examples:
            #   /Server Key = Name                
            #   /Server/Database Key = ServerName, Name
            #   /Server/Mail/MailProfile = ServerName, Name (as Mail does not have a key)
            #   /Server/Database/User/DefaultLanguage (no Urn) = ServerName, DatabaseName, UserName

            # This is the key itself
            $keyPropertyValue = $keyProperty.Value.Value

            if (!$table.Columns[$keyPropertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $keyPropertyName
                # It recognises all of these automatically Number but I populate them for prosperity anyway
                $column.DataType = switch ($keyProperty.Value.ObjType) { "String" { "System.String" } "Boolean" { "System.Boolean" } "Number" { "System.Int32" } } 
                # Not a bug, use -eq instead of -is
                if ($column.DataType -eq [string]) { 
                    $column.MaxLength = 128
                }
                $table.Columns.Add($column)

                Write-Verbose "$($tab)Key $keyPropertyName added"
            } else {
                Write-Verbose "$($tab)Key $keyPropertyName already exists"
            }
            $primaryKeyColumns += $table.Columns[$keyPropertyName]

            # Our local foreign key columns are everything except the last key (unless we have no Urn, in which case the last key doesn't exist yet)
            if ($i -ne ($urn.XPathExpression.Length - 1) -or !$InputObject.psobject.Properties["Urn"]) {
                $foreignKeyColumns += $table.Columns[$keyPropertyName]
            }

            if ($keyPropertyValue -eq $null) {
                Write-Error "$($tab)Null value in primary key, this shouldn't happen"
            } else {
                $row[$keyPropertyName] = $keyPropertyValue
            }
        }
    }
    # Finished looping primary keys

    "(Primary Key)" | Add-PerformanceRecord $performancePrimaryKey
    $performanceProperties = Get-Date

    # Get a list of properties to process; but remove the ones that match the wildcards in our exclusion list
    $performanceExclude = Get-Date
    $properties = $InputObject.psobject.Properties | Where { $SmoDbPropertyExclusions -notcontains $_.Name -and $SmoDbPathExclusions -notcontains "$path/$($_.Name)" }
    "(Performance Exclude)" | Add-PerformanceRecord $performanceExclude
    # Write-Debug "$($tab)Properties $($properties | Select -ExpandProperty Name)"

    <#
    # SMO throws an exception when it automatically creates some objects in collections, like Certificates, 
    # and you try to iterate through them without populating them first.
    # Examples:
    # [Microsoft.SqlServer.Management.Smo.DatabaseEncryptionKey]
    # [Microsoft.SqlServer.Management.Smo.EndpointPayload]
    # [Microsoft.SqlServer.Management.Smo.EndpointProtocol]
    # $smo.Endpoints[0].Protocol.Http # To accomplish this action, set property AuthenticationRealm.
    #
    # But:
    # a) I've removed State from the properties collection so this is never triggered
    # b) It doesn't trigger if you access the bits and peices; it triggers when you access the
    #    Properties collection (and stuff like that), which we never do. So this is now safe
    #    to proceed without this test.
    if ($properties | Where { $_.Name -eq "State" -and $_.Value -eq "Creating" }) {
        Write-Verbose "$($tab)Skipping row in $path because it does not have existing records"
        return
    }
    #>

    $writeRow = $true
    $recurseProperties = @()
    foreach ($property in $properties) {
        $propertyName = $property.Name
        $propertyType = $property.TypeNameOfValue

        # These are handled as properties on the main object, the real property collection doesn't need to be touched
        if ($propertyType.StartsWith("Microsoft.SqlServer.Management.Smo.") -and $propertyType.EndsWith("PropertyCollection")) {
            Write-Debug "$($tab)Completely skipping $propertyName as it is a property collection"
            continue
        }
        # SMO has a bug which throws an exception if you try to iterate through this property. Instead we redirect it to use
        # the one in Server/Settings which is more reliable. We already did the exclusion check so it's not impacted here.
        if ($propertyName -eq "OleDbProviderSettings" -and $propertyType -eq "Microsoft.SqlServer.Management.Smo.OleDbProviderSettingsCollection") {
            $property = $InputObject.Settings.psobject.Properties["OleDbProviderSettings"]
        }

        $propertyValue = $property.Value  

        # This addresses specific Server/Configuration entries which have not been filled out, causing an exception
        # when you add them to the table while constraints exist.
        if ($propertyType -eq "Microsoft.SqlServer.Management.Smo.ConfigProperty") { # It's important to use this instead of a check; because UserInstanceTimeout can be a Null value type
            if ($propertyValue -eq $null -or $propertyValue.Number -eq 0) {
                Write-Debug "$($tab)Skipping config property $propertyName with value $propertyValue because it's invalid"
                continue
            } else {
                Write-Debug "$($tab)Processing config property $propertyName"

                $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth $path $propertyName $parentPrimaryKeyColumns
                $writeRow = $false
                continue
                # We don't return because we want to continue processing all of the other properties in this way.
                # However we also don't want to write the row at the end because it's empty, so we set a special flag 
                # not to.
            }
        } elseif ($propertyValue -is [System.Collections.ICollection] -and $propertyValue -isnot [System.Byte[]]) {
            Write-Debug "$($tab)Processing property $propertyName collection"

            # It's possible for it to be null, which is okay, and worth trying to iterate... maybe... I should test this
            if ($propertyValue.Count -eq 0) {
                continue
            }
          
            $recurseProperties += $property
            continue
        } else {
            # We can handle [System.Byte[]] as Varbinary, and we manually skip the collection portion/other properties later
            if (!$table.Columns[$propertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $propertyName
                
                # When adding a column don't jump directly to checking $propertyValue as it may still be null.

                if ($property.MemberType -eq "ScriptProperty") { # Used on IpAddressToString
                    $columnDataType = "System.String"
                } else {
                    $columnDataType = Get-SmoDataSetType $propertyType
                }
                if (!$columnDataType) {
                    # If we don't haev the right data type, then we can't, by definition, add the column
                    Write-Debug "$($tab)Skipped writing out the raw column because it doesn't look right; it may be recursed instead"

                    if ($propertyValue -eq $null) {
                        continue
                    } else {
                        $recurseProperties += $property
                        continue
                    }
                }

                $column.DataType = $columnDataType
                $table.Columns.Add($column)
            }

            # If it's null we don't need to set it because it defaults to [DBNull]::Value anyway (probably). Also, always
            # maybe sure to check -(n)e(q) $null because $propertyValue could be a boolean, and false's would then not be
            # written out.
            if ($propertyValue -ne $null) {
                Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue"
    
	        	# This is how SMO represents null dates; a 0000 date or a 1900 date. Both are converted to null.
                if ($propertyValue -isnot [System.DateTime] -or @(599266080000000000, 0) -notcontains $propertyValue.Ticks) {
                    $row[$propertyName] = $propertyValue
                }
            }
        }
    }
    # Finished first round of adding properties and values
    "(Properties)" | Add-PerformanceRecord $performanceProperties
    $path | Add-PerformanceRecord $performanceProperties
    $performanceConstraints = Get-Date

    # Do primary key fixups (additional key columns) for properties without a full Urn. this has to be done
    # after all of the properties have been looped above, otherwise the column won't exist yet (we could
    # create it but then we need to think of data types again, and duplicates effort).
    switch ($tableName) {
        "Configuration" {
            # Because we flattened it; it doesn't have a natural key
            $primaryKeyColumns += $table.Columns["Number"]
            break
        }

        "Cpus" {
            # Because it doesn't have a Urn; Id is the Id of each single CPU
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "NumaNodes" {
            # Because it doesn't have a Urn; Id is the Id of each single Numa Node
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "NumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
            break
        }

        "ResourcePoolCpus" {
            # Because it doesn't have a Urn. I think that Id is the Cpu Id in both columns but it wasn't clear.
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["Id"]
            break
        }
        "ResourcePoolNumaNodes" {
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "ResourcePoolNumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
            break
        }

        "Schedulers" {
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
    }

    # If there's no primary key on the table already then we'll add it
    try {
        if (!$table.PrimaryKey) {
            Write-Verbose "$($tab)Creating primary key"
            [void] ($table.Constraints.Add("PK_$tableName", $primaryKeyColumns, $true))
        
            # Check we have foreign keys to create (we wouldn't, for example, on Server) and that no foreign key exists yet.
            if ($foreignKeyColumns.Count -gt 0 -and !($table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint]})) {
                $foreignKeyName = "FK_$($tableName)_$($ParentPrimaryKeyColumns[0].Table.TableName)"
                Write-Verbose "$($tab)Creating foreign key $foreignKeyName"

                $foreignKeyConstraint = New-Object System.Data.ForeignKeyConstraint($foreignKeyName, $ParentPrimaryKeyColumns, $foreignKeyColumns)
                [void] ($table.Constraints.Add($foreignKeyConstraint))
            }
        }
    } catch {
        # Choke point for exceptions
        Write-Error "$($tab)Exception: $(Resolve-Error -AsString)"
    }
    "(Constraints)" | Add-PerformanceRecord $performanceConstraints

    # Part 2 is where we go through and start recursing things
    foreach ($property in $recurseProperties) {
        $propertyName = $property.Name
        $propertyValue = $property.Value  
        Write-Verbose "$($tab)Recursing through $propertyName collection"

        if ($propertyValue -is [System.Collections.ICollection]) {
            try {
                foreach ($item in $propertyValue.GetEnumerator()) {
                    $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $primaryKeyColumns
                }
            } catch {
                if (Test-Error Microsoft.SqlServer.Management.Sdk.Sfc.InvalidVersionEnumeratorException) {
                    # e.g. Availability Groups on lower versions of SQL Server
                    Write-Verbose "$($tab)Collection not valid on this version."
                } elseif (Test-Error System.UnauthorizedAccessException) {
                    Write-Error "$($tab)Administrator (or other) permission required to use WMI."
                } elseif (Test-Error @{ ErrorCode = "InvalidNamespace" }) {
                    Write-Error "SMO 2014 bug connecting to WMI on SQL Server 2012."
                } elseif (Test-Error @{ Number = 954; Class = 14; State = 1 }) {
                    Write-Verbose "$($tab)Unable to enumerate the collection, due to mirroring/AGs."
                } else {
                    Write-Error "$($tab)Exception: $(Resolve-Error -AsString)"
                }
            }
        } elseif ($tableName -eq "Configuration") {
            # We have a special case for this. Because we're flattening it into one table, we need to pass
            # the parent primary key columns, instead of our own.
            Write-Error "$($tab)This isn't supposed to be used anymore; $(Resolve-Error -AsString)"
        } elseif ($propertyValue -is [System.Array]) {
            foreach ($item in $propertyValue) {
                Write-Verbose "$($tab)Recursing through array node"
                $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $primaryKeyColumns
            }    
        } else {
            Write-Verbose "$($tab)Recursing through non-array node"
            $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth $path $propertyName $primaryKeyColumns
        }
    }
    # Finished looping properties

    # We set an exception not to write the row if it's part of the Configuration collection (as we write them separately)
    if ($writeRow) {
        Write-Verbose "$($tab)Writing row for $tableName"
        
        try {
            $table.Rows.Add($row)
        } catch {
            # Choke point for exceptions
            Write-Error "$($tab)Exception: $(Resolve-Error -AsString)"
        }
    }

    if ($table.Columns.Count -le $urn.XPathExpression.Length) {
        Write-Debug "$($tab)$tableName was empty except for keys"
    }

    Write-Verbose "$($tab)Return"
    $OutputObject
}
