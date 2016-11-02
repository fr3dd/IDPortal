#########################################################################
#
# TITLE: IDPortal Cmdlets
# DESCRIPTION: Provides a PowerShell-friendly use of FIMAutomation
# AUTHOR:  Fred Duncan (fr3dd)
# COMPANY: Blue Chip Consulting Group, LLC
# WEBSITE: http://www.bluechip-llc.com
# VERSION: 2.0.2016.1028
#
#Requires -Version 2.0
#Requires -PSSnapin FIMAutomation
#########################################################################

# Determine if the required snap-in is registered
[Object] $snapIn = Get-PSSnapin -Registered -Name 'FIMAutomation' -ErrorAction SilentlyContinue;

# Determine if the Snap-in is registered, then load the complementing cmdlets
if ( $snapIn -ne $null )
{
    # Add PSSnapin
    Add-PSSnapin -Name 'FIMAutomation';

	# Build a temporary variable for a data directory
	[String] $tempDirectory = "{0}\IDPortal" -f $Env:APPDATA;
	
	# Determine if the directory is present
	if ( ( Test-Path -Path $tempDirectory ) -eq $false )
    {
		# Create the directory path
		New-Item -Path $tempDirectory -ItemType Directory;
	}
	
	# Initialize global variables 
	Set-Variable -Name IDPortalCredential -Option AllScope -Scope Global -Value $null;
	Set-Variable -Name IDPortalDataDirectory -Option AllScope -Scope Global -Value $tempDirectory;
	Set-Variable -Name IDPortalServiceUri -Option AllScope -Scope Global -Value "http://localhost:5725/ResourceManagementService";

    Write-Host "`n`n================================================================================" -ForegroundColor Green;
    Write-Host '  Snap-in detected: FIMAutomation' -ForegroundColor Green;
    Write-Host "================================================================================`n" -ForegroundColor Green;
    Write-Host '  Additional Module Variables' -ForegroundColor Green;
    Write-Host '  ---------------------------' -ForegroundColor Green;
    Write-Host ( "  `$IDPortalCredential: {0}" -f $IDPortalCredential ) -ForegroundColor Green;
    Write-Host ( "  `$IDPortalDataDirectory: {0}" -f $IDPortalDataDirectory ) -ForegroundColor Green;
    Write-Host ( "  `$IDPortalServiceUri: {0}`n" -f $IDPortalServiceUri ) -ForegroundColor Green;
    Write-Host '  Schema File Information' -ForegroundColor Green;
    Write-Host '  --------------------------' -ForegroundColor Green;

	# Collect schema file information
	[String] $keyName = $null;
	[String] $keyValue = $null;
	
	# Read the directory and get each file
	Get-ChildItem -Path $IDPortalDataDirectory -Filter 'Schema-*.xml' | ForEach-Object {
		$keyName = $_.Name -replace "Schema-", "";
		$keyName = $keyName -replace ".xml", "" ;
		$keyValue = $_.LastWriteTime.ToString( "MM-dd-yyyy hh:mm tt" );
		Write-Host ( "  {0}: {1}" -f $keyName, $keyValue ) -ForegroundColor Green;
	}
	Write-Host "================================================================================`n`n" -ForegroundColor Green;

	#region Add Cmdlets

	function Add-IDPortalObjectSID
    {
			[CmdletBinding()]
			Param
            (
				[Parameter( Mandatory = $true, HelpMessage = "Specify the account name to retrieve the SID from." )]
				[String] $AccountName = $(throw "Missing required parameter -AccountName"),
			
				[Parameter( Mandatory = $true, HelpMessage = "Specify the domain to retrieve the SID from." )]
				[String] $Domain = $(throw "Missing required parameter -Domain"),
				
				[Parameter( Mandatory = $true, HelpMessage = "Please specify the FIM/MIM ObjectID of the target Person object." )]
				[String] $ObjectID = $(throw "Missing required parameter -ObjectID"),
								
				[Parameter( Mandatory = $false, HelpMessage = "Please specify is a non-matching SID should be overwritten.")]
				[Boolean] $Confirm = $true
			)
			Begin
            { }
			End
            {
				# Declare local objects and variables
				[String] $filter = "/*[ObjectID='{0}']" -f $ObjectID
				[Object] $fimObject = Get-IDPortalObject -Filter $filter;
				[String] $result = $null;
				[Object] $output = New-Object Management.Automation.PSObject;
				[Boolean] $processUpdate = $false;
				[Object] $sidInfo = _GetADObjectSID -AccountName $AccountName -Domain $Domain;
				
				# Determine if the SID was found
				if ( $sidInfo.Result -eq 'Object not found!' )
                {
					$result = 'The source ObjectSID was not found';
				}
                else
                {
					# Determine if the FIM/MIM Person object was returned
					if ( $fimObject -eq $null )
                    {
						$result = 'The source ObjectID was not found';
					}
                    else
                    {
						# Determine if the ObjectSID is already set
						if ( [String]::IsNullOrEmpty( $fimObject.ObjectSID ) )
                        {
							# Update the flag to set the SID
							$processUpdate = $true;
						}
                        else
                        {
							# Compare the values
							if ( $fimObject.ObjectSID -ne $sidInfo.Base64 )
                            {
								# Determine if the value should be overwritten
								if ( $Confirm )
                                {
									# Define confirmation choices
									$yes = New-Object Management.Automation.Host.ChoiceDescription "&Yes", "Overwrites existing SID with new SID";
									$no = New-Object Management.Automation.Host.ChoiceDescription "&No", "Do not overwrite existing SID";
									
									# Build the options
									$promptChoices = [Management.Automation.Host.ChoiceDescription[]]( $yes, $no );
									
									# Prompt for choices
									try
                                    {
										$promptResponse = $Host.UI.PromptForChoice( 'Confirm Action', 'ObjectSID is already set and does not match.  Do you want to overwrite it?', $promptChoices, 1 );
									}
                                    catch [Management.Automation.Host.PromptingException]
                                    {
										# Cancel the update if user cancels the choice
										$writeSIDToFIMPerson = $false;
										$result = 'The existing ObjectSID does not match the provided account';
									}
									
									# Determine what to do based on the response
									switch ( $promptResponse )
                                    {
										0
                                        {
                                            $processUpdate = $true;
                                        }
										1
                                        {
                                            $result = 'The existing ObjectSID does not match the provided account';
                                        }
									} # end choice and determination
								}
                                else
                                {
									# Update the flag to set the SID
									$processUpdate = $true;
								}# end confirmation
							}
                            else
                            {
								$result = 'ObjectSID is already set';
							}
						} # end comparison
					} # Person returned
				} # end SID addition
				
				# Determine if the value should be written to the FIM/MIM Portal
				if ( $processUpdate )
                {
					# Create the required import objects
					[Object] $importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange;
					[Object] $importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
					
					# Prepare the change operation
					$importChange.Operation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]::Replace;
					$importChange.AttributeName = "ObjectSID";
					$importChange.AttributeValue = $sidInfo.Base64;
					$importChange.FullyResolved = 1;
					$importChange.Locale = "Invariant";
					
					# Prepare the import object
					$importObject.ObjectType = $fimObject.ObjectType;
					$importObject.TargetObjectIdentifier = $fimObject.ObjectID;
					$importObject.SourceObjectIdentifier = $fimObject.ObjectID;
					$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Put;
					$importObject.Changes = (,$importChange);
					
					# Perform the update
					try
                    {
						if ( $IDPortalCredential -eq $null )
                        {
							$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
						}
                        else
                        {
							$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
						}
						$result = 'Success';
					}
                    catch [Exception]
                    {
						$result = $_.Exception.Message;
					} # end update
				} # end update
				
				# Add result to the output object
				$output | Add-Member -MemberType NoteProperty -Name AccountName -Value $AccountName;
				$output | Add-Member -MemberType NoteProperty -Name Domain -Value $Domain.ToUpper();
				$output | Add-Member -MemberType NoteProperty -Name ObjectID -Value $ObjectID;
				$output | Add-Member -MemberType NoteProperty -Name Result -Value $result;
				
				# Write the output object
				Write-Output $output;
			} # end End
			
			<#
			    .SYNOPSIS
				    Provides a assign an ObjectSID to a FIM/MIM Person object.
			    .DESCRIPTION
				    This cmdlet is intended to provide a way to set the ObjectSID on a FIM/MIM Person object.  This is
				    one of the requirements to having access to the FIM/MIM Portal.
			    .PARAMETER AccountName
				    This is a mandatory parameter which contains the Account which the SID should be retrieved for.
			    .PARAMETER Domain
				    This is a mandatory parameter which contains the Domain which the SID should be retrieved for.
			    .PARAMETER ObjectID
				    This is a mandatory parameter which contains the ObjectID of the FIM/MIM Person object to apply the
				    looked up SID to.
			    .INPUTS
				    This cmdlet utilizes two new variables which are created and initialized during module import.
					    $IDPortalCredential = $null;	# will use current user
					    $IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
				    You will need to update these prior to calling this cmdlet to ensure appropriate results.
			    .OUTPUTS
				    This cmdlet returns an object with properties and methods which contain information about the 
				    FIM/MIM Person object.  The returned object contains a GetAttribute method that allows you to retrieve
				    unlisted attributes providing it has a value.
			    .NOTES
				    To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
				    To see more information, type: "Get-Help [cmdlet name] -detail"
				    To see technical information, type: Get-Help [cmdlet name] -full"
			    .EXAMPLE
				    $accountName = 'foo';
				    $domain = 'bar';
				    [Object] $myPerson = Get-IDPortalObject -Filter "/Person[LastName='Duncan']";
				    [Object] $addSID = Add-IDPortalObjectSID -AccountName $accountName -Domain $domain -ObjectID $myPerson.ObjectID -ObjectType 'Person' -Confirm:$false;
				
				    The preceeding example adds a SID to a FIM/MIM Person object.
			    .LINK
				    Company website: http://www.bluechip-llc.com
			#>
		} # end Add-IDPortalObjectSID

	# Export the cmdlet
	Export-ModuleMember -Function Add-IDPortalObjectSID;

	#endregion
	
	#region Get Cmdlets

    function _GetADObjectSID
    {
	    [CmdletBinding()]
	    Param(	
		    [Parameter( Mandatory = $true, HelpMessage = "Specify the account name to retrieve the SID from.", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
		    [String] $AccountName = $(throw "Missing required parameter -AccountName"),
	
		    [Parameter( Mandatory = $true, HelpMessage = "Specify the domain to retrieve the SID from.", ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true )]
		    [String] $Domain = $(throw "Missing required parameter -Domain")	
	    )
	    Begin
        { }
	    End
        {
		    # Declare local objects and variables
		    [String] $accountSID = $null;
		    [Object] $adAccount = $null;
		    [Security.Principal.SecurityIdentifier] $adSID = $null;
		    [String] $base64SID = $null;
		    [String] $domainAccount = "{0}\{1}" -f $Domain.ToUpper(), $AccountName;
		    [String] $domainSID = $null;
		    [Array] $hexBytes = $null;
		    [String] $hexString = $null;
		    [Object] $output = New-Object Management.Automation.PSObject;
		    [String] $result = $null;
		
		    # Get a reference to the AD account
		    $adAccount = New-Object Security.Principal.NTAccount( $domainAccount );
		
		    # Translate the SID into a usable form
		    try
            {
			    $adSID = $adAccount.Translate( [Security.Principal.SecurityIdentifier] );
			
			    # Retrieve the string SIDs for account and domain
			    $accountSID = $adSID.Value;
			    $domainSID = $adSID.AccountDomainSid.Value;
			
			    # Return the SID in byte format
			    [Byte[]] $sIDBytes = New-Object Byte[] -ArgumentList $adSID.BinaryLength;
			
			    # Return the binary form of the SID
			    $adSID.GetBinaryForm( $sIDBytes, 0 );
			
			    # Iterate through bytes, converting each to the hexidecimal equivalent
			    $hexBytes = $sIDBytes | ForEach-Object { $_.ToString( "X2" ) };

			    # Join the hex array into a single string for output
			    $hexString = "\" + ($hexBytes -join '\');

			    # Convert the binary data to a base 64 string
			    $base64SID = [Convert]::ToBase64String( $sIDBytes );
			
			    # Return the result
			    $result = 'Success';
		    }
            catch [Security.Principal.IdentityNotMappedException]
            {
			    # Update the result with not found
			    $result = 'Object not found!';
		    }
            catch [Exception]
            {
			    # Update the result with the default message
			    $result = $_.Exception.Message;
		    } # end translation

		    # Add result to the output object
		    $output | Add-Member -MemberType NoteProperty -Name AccountName -Value $AccountName;
		    $output | Add-Member -MemberType NoteProperty -Name AccountSID -Value $accountSID;
		    $output | Add-Member -MemberType NoteProperty -Name Base64 -Value $base64SID;
		    $output | Add-Member -MemberType NoteProperty -Name Binary -Value $sIDBytes;
		    $output | Add-Member -MemberType NoteProperty -Name DomainName -Value $Domain.ToUpper();
		    $output | Add-Member -MemberType NoteProperty -Name DomainSID -Value $domainSID;
		    $output | Add-Member -MemberType NoteProperty -Name HexBytes -Value $hexBytes;
		    $output | Add-Member -MemberType NoteProperty -Name HexString -Value $hexString;
		    $output | Add-Member -MemberType NoteProperty -Name LegacyName -Value $domainAccount;
		    $output | Add-Member -MemberType NoteProperty -Name Result -Value $result;
		
		    # Add a method to return the Base64Sid property 'ToString()'	
		    $output | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.AccountSID } -Force;
		
		    # Write the output object
		    Write-Output $output;
	    }
    }

	function Get-IDPortalObject
    {
		[CmdletBinding()]
		Param(	
			[Parameter( Mandatory = $true, HelpMessage = "Please specify the FIM/MIM XPath filter to use." )]
			[String] $Filter = $(throw "Missing required parameter -Filter"),
				
			[Parameter( Mandatory = $false, HelpMessage = "This switch will return only attributes that have values." )]
			[switch] $HasValue = $false
		)
		Begin
        { }
		End
        {
			# Declare local objects and variables
			[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject[]] $exportObjects = $null;
								
			# Connect to the FIM/MIM Service and perform the search
			try
            {
				if ( $IDPortalCredential -eq $null )
                {
					$exportObjects = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $Filter;
				}
                else
                {
					$exportObjects = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $Filter -Credential $IDPortalCredential;
				}
			}
            catch [InvalidOperationException]
            {
				$result = 'Failed to connect with web service';
			} # end connect to the FIM/MIM Service
				
			# Retrieve the attribute values if an object was returned
			if ( $exportObjects -ne $null )
            {
				# Iterate through each object
				$exportObjects | ForEach-Object {
					# Initialize objects and variables for each object
					[String] $currentAttribute = $null;
					[Object] $currentValue = $null;
					[String] $displayName = $null;
					[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject] $exportObject = $_;
					[String] $key = $null;
					[String] $objectID = $exportObject.ResourceManagementObject.ObjectIdentifier -replace "urn:uuid:", "";
					[String] $objectType = $exportObject.ResourceManagementObject.ObjectType;
					[Hashtable] $objectAttributes = @{};
					[Object] $output = New-Object Management.Automation.PSObject;
					[String] $schemaFile = "{0}\Schema-{1}.xml" -f $IDPortalDataDirectory, $objectType;
					[Boolean] $schemaRetrieved = $false;
						
					# Check for a schema definition file
					if ( Test-Path -Path $schemaFile )
                    {
						$schemaRetrieved = $true;
					}
                    else
                    {
						'================================================================================';
						"  Retrieving '$objectType' object schema...";
						"================================================================================`n";
							
						# Retrieve the schema
						if ( Get-IDPortalSchema -ObjectType $objectType )
                        {
							$schemaRetrieved = $true;
						}
					} # end schema test
						
					# Determine if blank values should be returned by inspecting the optional -HasValue switch
					if ( $HasValue )
                    {
						$schemaRetrieved = $false;
					}
						
					# Restrieve the object schema attributes
					if ( $schemaRetrieved )
                    {
						try
                        {
							# Read in the schema data to build properties
							[Management.Automation.PSObject[]] $schemaAttributes = Import-Clixml -Path $schemaFile;
								
							# Prepare the attribute/value pairs
							[String] $currentDataType = $null;
							[Hashtable] $dataType = @{};
							[Hashtable] $initialValues = @{};
							[Boolean] $isMultiValued = $false;
							[Hashtable] $multivalued = @{};
							[Object] $singleValue = $null;
								
							# Build hashtables for data parsing
							$schemaAttributes | ForEach-Object {
								# Get the key value for the attribute/value pairs
								$key = $_.Name;
									
								# Add to the attribute/value pairs only if the key name is defined
								if ( -not ( [String]::IsNullOrEmpty( $key ) ) )
                                {
									# Add to data type pair
									$dataType.Add( $key, $_.DataType );
										
									# Add to initization pair
									$initialValues.Add( $key, $null );
										
									# Add to initization pair
									$multivalued.Add( $key, $_.Multivalued );
								} # end empty check
							} # end schema parsing
																
							# Iterate through the object and set return object property values
							for ( $currentIndex = 0; $currentIndex -le ( $exportObject.ResourceManagementObject.ResourceManagementAttributes.Count - 1 ); $currentIndex++ )
                            {
								# Retrieve the current attribute name
								$currentAttribute = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).AttributeName;
									
								# Retrieve the current data type
								$currentDataType = $dataType.get_Item( $currentAttribute );
									
								# Retrieve the multivalued status
								$isMultiValued = [Convert]::ToBoolean( $multivalued.get_Item( $currentAttribute ) );
									
								# Determine if the value is multivalued
								if ( $isMultiValued )
                                {
									# Determine if it is a reference
									if ( $currentDataType -eq 'Reference' )
                                    {
										# Build an empty array object
										#[Array] $valueCollection = @();
                                        $valueCollection = New-Object Collections.ArrayList;
											
										# Reset currentValue to null;
										$currentValue = $null;
											
										# Iterate through the values
										$exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Values | ForEach-Object {
											# Strip the unnecessary moniker
											$singleValue = $_ -replace "urn:uuid:", "";
												
											# Add to the return array
											#$valueCollection += $singleValue;
                                            [Void] $valueCollection.Add( $singleValue );
										} # end iterating through the values
										
										# Return the current attribute value
										$currentValue = $valueCollection;
									}
                                    else
                                    {
										# Return the current attribute value
										$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Values;
									}
								}
                                else
                                {
									# Determine if it is a reference
									if ( $currentDataType -eq 'Reference' )
                                    {
										# Return the current attribute value
										$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value -replace "urn:uuid:", "";;
									}
                                    else
                                    {
										# Return the current attribute value
										$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value;
									}
								}
									
								# Update the values table with the current attribute/value pair
								$initialValues.set_Item( $currentAttribute, $currentValue );
							} # end for loop
								
							# Build output object by iterating through the attribute/value pair
							$initialValues.GetEnumerator() | Sort-Object Name | ForEach-Object {
								# Add as a property on the output object
								$output | Add-Member -MemberType NoteProperty -Name $_.Key -Value $_.Value | Add-Member -MemberType ScriptProperty -Value { $this.$($_.Key);}{ $this.$($_.Key) = $args[0]; };
							}
								
						}
                        catch [Xml.XmlException]
                        {
							# Add result to the output object
							$output | Add-Member -MemberType NoteProperty -Name ObjectID -Value $objectID;
							$output | Add-Member -MemberType NoteProperty -Name ObjectType -Value $objectType;
							$output | Add-Member -MemberType NoteProperty -Name Result -Value 'Invalid schema file for current object';
						}
					}
                    else
                    { # Return an object with the current set attributes
						# Prepare the attribute/value pairs
						[Boolean] $isMultiValued = $false;
						[Object] $singleValue = $null;
						
						#Iterate through the object and set return object property values
						for ( $currentIndex = 0; $currentIndex -le ( $exportObject.ResourceManagementObject.ResourceManagementAttributes.Count - 1 ); $currentIndex++ )
                        {
							# Retrieve the current attribute name
							$currentAttribute = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).AttributeName;
								
							# Determine if the attribute is a multivalue attribute
							$isMultiValued = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).IsMultiValue;
								
							# Determine if the attribute multiple values should be returned
							if ( $isMultiValued )
                            {
								# Determine if the attrubute value contains a reference and if so strip prefix from each value
								# Build an empty array object
								#[Array] $valueCollection = @();
                                $valueCollection = New-Object Collections.ArrayList;
									
								# Reset currentValue to null;
								$currentValue = $null;
									
								# Iterate through the values
								$exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Values | ForEach-Object {
									# Strip the unnecessary moniker
									$singleValue = $_ -replace "urn:uuid:", "";
										
									# Add to the return array
									#$valueCollection += $singleValue;
                                    [Void] $valueCollection.Add( $singleValue );
								} # end iterating through the values
									
								# Return the current attribute value
								$currentValue = $valueCollection;
							}
                            else
                            { # Single value
								# Determine if the attrubute is a reference and if so strip prefix
								$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value -replace "urn:uuid:", "";
							}

							# Add as a property on the output object
							$output | Add-Member -MemberType NoteProperty -Name $currentAttribute -Value $currentValue;
						} # end for loop
					}
						
					# Add a method to add a value to a multivalue attribute
					$output | Add-Member -MemberType ScriptMethod -Name AddMultiValue {
						Param(	
							[Parameter( Mandatory = $true, HelpMessage = "Please specify the attribute name." )]
							[String] $Name = $(throw "Missing required parameter -Name"),
								
							[Parameter( Mandatory = $true, HelpMessage="Please specify the attribute value." )]
							[String] $Value = $(throw "Missing required parameter -Value")
						)
						End
                        {
							# Declare method objects and variables
                            $valueCollection = New-Object Collections.ArrayList;
                            $valueCollection.AddRange( $this.$Name );
							[Object] $setResult = Set-IDPortalAttribute -AttributeName $Name -AttributeValue $Value -ObjectID $this.ObjectID -ObjectType $this.ObjectType -Remove:$false;
							
                            # Update the object if successful
                            if ( $setResult.Result -eq 'Success' )
                            {
                                [Void] $valueCollection.Add( $Value );
                                $this.$Name = $valueCollection;
                            }

							# Return the method result value
							return $setResult.Result;
						} # end End
					} -Force;

					# Add a method to remove a value to a multivalue attribute
					$output | Add-Member -MemberType ScriptMethod -Name RemoveMultiValue {
						Param(	
							[Parameter( Mandatory = $true, HelpMessage = "Please specify the attribute name." )]
							[String] $Name = $(throw "Missing required parameter -Name"),
								
							[Parameter( Mandatory = $true, HelpMessage="Please specify the attribute value." )]
							[String] $Value = $(throw "Missing required parameter -Value")
						)
						End
                        {
							# Declare method objects and variables
                            $valueCollection = New-Object Collections.ArrayList;
                            $valueCollection.AddRange( $this.$Name );
							[Object] $setResult = Set-IDPortalAttribute -AttributeName $Name -AttributeValue $Value -ObjectID $this.ObjectID -ObjectType $this.ObjectType -Remove:$true;
							
                            # Update the object if successful
                            if ( $setResult.Result -eq 'Success' )
                            {
                                $valueCollection.Remove( $Value );
                                $this.$Name = $valueCollection;
                            }

							# Return the method result value
							return $setResult.Result;
						} # end End
					} -Force;		
						
					# Add a method to set an attribute value
					$output | Add-Member -MemberType ScriptMethod -Name SetAttribute {
						Param(	
							[Parameter( Mandatory = $true, HelpMessage="Please specify the attribute name." )]
							[String] $Name = $(throw "Missing required parameter -Name"),
								
							[Parameter( Mandatory = $false, HelpMessage = "Please specify the attribute value." )]
							[String] $Value
						)
						End
                        {
							# Declare method objects and variables
							[Object] $setResult = Set-IDPortalAttribute -AttributeName $Name -AttributeValue $Value -ObjectID $this.ObjectID -ObjectType $this.ObjectType;
							
                            # Update the object if successful
                            if ( $setResult.Result -eq 'Success' )
                            {
                                $this.$Name = $Value;
                            }

							# Return the method result value
							return $setResult.Result;
						} # end End
					} -Force;
			
					# Add a method to set an attribute value
					$output | Add-Member -MemberType ScriptMethod -Name SetSID {
						Param(
							[Parameter( Mandatory = $true, HelpMessage = "Please specify the Active Directory account name." )]
							[String] $AccountName = $(throw "Missing required parameter -AccountName"),
								
							[Parameter( Mandatory = $true, HelpMessage="Please specify the Active Directory  NetBIOS domain name." )]
							[String] $Domain = $(throw "Missing required parameter -Domain")
						)
						End
                        {
							# Declare method objects and variables
							[Object] $setResult = Add-IDPortalObjectSID -AccountName $accountName -Domain $Domain -ObjectID $this.ObjectID -Confirm:$false;
								
							# Return the method result value
							return $setResult.Result;
						} # end End
					} -Force;		
			
					# Write the output object
					Write-Output $output;
						
				} # each object
			} # end attribute value retrieval
		} # end End
			
		<#
		    .SYNOPSIS
			    Provides a way to retrieve a FIM/MIM Portal Person with an XPath query.
		    .DESCRIPTION
			    This cmdlet is intended to provide a way to return a reference to a FIM/MIM Portal object based on the
			    result of an XPath query.
		    .PARAMETER AttributeName
			    This is a mandatory parameter which contains the XPath Person attribute to search for.
		    .PARAMETER AttributeValue
			    This is a mandatory parameter which contains the XPath Person attribute value to search for.		
		    .INPUTS
			    This cmdlet utilizes two new variables which are created and initialized during module import.
				    $IDPortalCredential = $null;	# will use current user
				    $IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
			    You will need to update these prior to calling this cmdlet to ensure appropriate results.
		    .OUTPUTS
			    This cmdlet returns an object with properties and methods which contain information about the 
			    FIM/MIM Person object.  The returned object contains a GetAttribute method that allows you to retrieve
			    unlisted attributes providing it has a value.
		    .NOTES
			    To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
			    To see more information, type: "Get-Help [cmdlet name] -detail"
			    To see technical information, type: Get-Help [cmdlet name] -full"
		    .EXAMPLE
			    [Object[]] $myPerson = Get-IDPortalObject -Filter "/Person[FirstName='Sean']";
				
			    The preceeding example performs an XPath query and returns all matching objects
		    .LINK
			    Company website: http://www.bluechip-llc.com
		#>
	} # end Get-IDPortalObject

	# Export the cmdlet
	Export-ModuleMember -Function Get-IDPortalObject;
		
	function Get-IDPortalSchema
    {
		[CmdletBinding()]
		Param(	
			[Parameter( Mandatory = $true, HelpMessage = "Please specify the FIM/MIM object type to return the schema for." )]
			[String] $ObjectType = $(throw "Missing required parameter -ObjectType")	
		)
		Begin
        { }
		End
        {
			# Declare local objects and variables
			[Array] $attributeNames = @();
			[Hashtable] $attributeInfo = @{};
			[Object[]] $outputCollection = New-Object Management.Automation.PSObject;
			[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject[]] $exportObjects = $null;
			[String] $requiredFilter = "/BindingDescription[BoundObjectType=/ObjectTypeDescription[Name='{0}']]" -f $ObjectType;
			[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject[]] $requiredAttributes = $null;
			[Hashtable] $requiredObjectAttributes = @{};
			[Boolean] $result = $false;
			[String] $schemaFile = "{0}\Schema-{1}.xml" -f $IDPortalDataDirectory, $ObjectType;
			[String] $searchFilter = "/BindingDescription[BoundObjectType=/ObjectTypeDescription[Name='{0}']]/BoundAttributeType" -f $ObjectType;
				
			# Connect to the FIM/MIM Service and perform the search
			try
            {
				if ( $IDPortalCredential -eq $null )
                {
					$exportObjects = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $searchFilter;
				}
                else
                {
					$exportObjects = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $searchFilter -Credential $IDPortalCredential;
				}
			}
            catch [InvalidOperationException]
            {
				return $result;
			} # end connect to the FIM/MIM Service
				
			# Retrieve the attribute values if an object was returned
			if ( $exportObjects -ne $null )
            {
				# Connect to the FIM/MIM Service and perform the search for the 
				try
                {
					if ( $IDPortalCredential -eq $null )
                    {
						$requiredAttributes = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $requiredFilter;
					}
                    else
                    {
						$requiredAttributes = Export-FIMConfig -Uri $IDPortalServiceUri -OnlyBaseResources -CustomConfig $requiredFilter -Credential $IDPortalCredential;
					}
				}
                catch [InvalidOperationException]
                {
					return $result;
				} # end connect to the FIM/MIM Service
				
				# Iterate through each object
				$requiredAttributes | ForEach-Object {
					# Initialize objects and variables for each object
					[String] $attributeID = $null;
					[Boolean] $attributeRequired = $false;
					[String] $currentAttribute = $null;
					[String] $currentValue = $null;
					[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject] $requiredObject = $_;
						
					# Iterate through the object and set return object property values
					for ( $currentIndex = 0; $currentIndex -le ( $requiredObject.ResourceManagementObject.ResourceManagementAttributes.Count - 1 ); $currentIndex++ )
                    {
						# Retrieve the current attribute name
						$currentAttribute = $requiredObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).AttributeName;
							
						# Determine whether the attribute is required by searching the object collection for the object Id
						if ( $currentAttribute -eq "DisplayName" )
                        {
							# Return the current attribute value
							$attributeID = $requiredObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value -replace "urn:uuid:", "";
						}
							
						# Determine whether the attribute is required by searching the object collection for the object Id
						if ( $currentAttribute -eq "Required" )
                        {
							# Return the current attribute value
							$attributeRequired = [Convert]::ToBoolean( $requiredObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value );
								
							# Add to the hash if both have values
							$requiredObjectAttributes.Add( $attributeID, $attributeRequired );
								
							# Re-initialize variables
							$attributeID = $null;
							$attributeRequired = $false;
						} # end required
					} # end for loop
				} # each object
					
				# Iterate through each object
				$exportObjects | ForEach-Object {
					# Initialize objects and variables for each object
					[String] $attributeType = $null;
					[String] $attributeName = $null;
					[String] $currentAttribute = $null;
					[String] $currentValue = $null;
					[Microsoft.ResourceManagement.Automation.ObjectModel.ExportObject] $exportObject = $_;
					[Object] $is = $null;
					[Object] $output = New-Object Management.Automation.PSObject;
						
					# Iterate through the object and set return object property values
					for ( $currentIndex = 0; $currentIndex -le ( $exportObject.ResourceManagementObject.ResourceManagementAttributes.Count - 1 ); $currentIndex++ )
                    {
						# Retrieve the current attribute name
						$currentAttribute = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).AttributeName;
							
						# Determine whether the attribute is required by searching the object collection for the object Id
						if ( $currentAttribute -eq "ObjectID" )
                        {
							# Return the current attribute value
							$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value -replace "urn:uuid:", "";
						}
                        else
                        {
							# Return the current attribute value
							$currentValue = $exportObject.ResourceManagementObject.ResourceManagementAttributes.Get( $currentIndex ).Value;
								
							if ( $currentAttribute -eq "DisplayName" )
                            {
								# Add as a property on the output object
								$output | Add-Member -MemberType NoteProperty -Name Required -Value $requiredObjectAttributes.get_Item( $currentValue );
							}
						}
														
						# Add as a property on the output object
						$output | Add-Member -MemberType NoteProperty -Name $currentAttribute -Value $currentValue;
					} # end for loop
						
					# Add the output object to the collection
					$outputCollection += $output;
				} # each object
			} # end object collection
				
			# Write the schema information to the specified file
			$outputCollection | Export-Clixml -Path $schemaFile -NoClobber:$false;
				
			# Update the return value and send it to the calling process
			$result = $true;
			return $result;
		} # end End
			
		<#
			.SYNOPSIS
				Provides a way to retrieve a FIM/MIM Portal Person with an XPath query.
			.DESCRIPTION
				This cmdlet is intended to provide a way to return a reference to a FIM/MIM Portal object based on the
				result of an XPath query.
			.PARAMETER ObjectType
				This is a mandatory parameter which contains the type of object to retrieve the schema for.		
			.INPUTS
				This cmdlet utilizes two new variables which are created and initialized during module import.
					$IDPortalCredential = $null;	# will use current user
					$IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
				You will need to update these prior to calling this cmdlet to ensure appropriate results.
			.OUTPUTS
				This cmdlet returns a boolean value indicating the success of the schema retrieval and creation
				of the corresponding 'Schema-<object>.xml file.
			.NOTES
				To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
				To see more information, type: "Get-Help [cmdlet name] -detail"
				To see technical information, type: Get-Help [cmdlet name] -full"
			.EXAMPLE
				Get-IDPortalSchema -ObjectType "Person";
				
				The preceeding example performs an XPath query and returns all matching objects
			.LINK
				Company website: http://www.bluechip-llc.com
		#>
	} # end Get-IDPortalSchema
		
	# Export the cmdlet
	Export-ModuleMember -Function Get-IDPortalSchema;

	#endregion
		
	#region New Cmdlets
		
	function New-IDPortalObject
    {
		[CmdletBinding()]
		Param(	
			[Parameter( Mandatory = $true, HelpMessage="Please specify the object type." )]
			[String] $ObjectType = $(throw "Missing required parameter -ObjectType"),
				
			[Parameter( Mandatory = $true, HelpMessage = "Please specify the properties and vaules by passing a hashtable." )]
			[Hashtable] $Properties = $(throw "Missing required parameter -Properties")
		)
		Begin
        { }
		End
        {
			# Declare local objects and variables
			[String] $newObjectID = $null;
			[Object] $output = New-Object Management.Automation.PSObject;
			[String] $result = $null;
			[Object] $setResult = $null;

			# Determine if the DisplayName was passed
			if ( [String]::IsNullOrEmpty( $Properties.DisplayName ) )
            {
				$result = 'Missing required attribute/value pair for DisplayName';
			}
            else
            {
				# Create the required import objects
				[Object] $importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange;
				[Object] $importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
					
				# Prepare the change operation
				$importChange.Operation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]::None;
				$importChange.AttributeName = 'DisplayName';
				$importChange.AttributeValue = $Properties.DisplayName;
				$importChange.FullyResolved = 1;
				$importChange.Locale = "Invariant";
					
				# Remove DisplayName from the Hashtable to prevent issues
				$Properties.Remove( 'DisplayName' );
					
				# Prepare the import object
				$importObject.ObjectType = $ObjectType;
				$importObject.TargetObjectIdentifier = [Guid]::Empty;
				$importObject.SourceObjectIdentifier = [Guid]::NewGuid().ToString();
				$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Create;
				$importObject.Changes = (,$importChange);
									
				# Perform the update
				try
                {
					if ( $IDPortalCredential -eq $null )
                    {
						$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
					}
                    else
                    {
						$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
					}
						
					# Retrieve the new object ID
					$newObjectID = $importObject.TargetObjectIdentifier -replace "urn:uuid:", "";
						
					# Iterate through the hash table and set the values on the new object
					$Properties.GetEnumerator() | ForEach-Object {
						# Add the attribute
						$setResult = Set-IDPortalAttribute -ObjectID $newObjectID -ObjectType $ObjectType -AttributeName $_.Key -AttributeValue $_.Value;
					}
					
					$result = 'Success';
				}
                catch [Exception]
                {
					$result = $_.Exception.Message;
				} # end update
			} # end DisplayName check
				
			# Add as a property on the output object
			$output | Add-Member -MemberType NoteProperty -Name ObjectID -Value $newObjectID;
			$output | Add-Member -MemberType NoteProperty -Name ObjectType -Value $ObjectType;
			$output | Add-Member -MemberType NoteProperty -Name Result -Value $result;
				
			# Write the output object
			Write-Output $output;
		} # end End
			
		<#
			.SYNOPSIS
				Provides a way to create a new FIM/MIM object.
			.DESCRIPTION
				This cmdlet is intended to provide a consistent method to create new FIM/MIM objects
			.PARAMETER ObjectType
				This is a mandatory parameter which contains the type of object that should be created.	
			.PARAMETER Properties
				This is a mandatory parameter which contains a hashtable of all the attributes / value pairs that should
				be assigned to the object.
			.INPUTS
				This cmdlet utilizes two new variables which are created and initialized during module import.
					$IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
				You will need to update these prior to calling this cmdlet to ensure appropriate results.
			.OUTPUTS
				This cmdlet returns an object indicating the success of the update operation.
			.NOTES
				To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
				To see more information, type: "Get-Help [cmdlet name] -detail"
				To see technical information, type: Get-Help [cmdlet name] -full"
			.EXAMPLE
				[Hashtable] $propertyBag = @{
					AccountName = 'jodoe';
					Domain = 'lab';
					FirstName = 'John';
					LastName = 'Doe';
					DisplayName = 'Doe, John';
				}
				
				[Object] $data = New-IDPortalObject -ObjectType "Person" -Properties $propertyBag;
				
				The preceeding example creates a new FIM/MIM Portal object and sets the respective attribute values.
			.LINK
				Company website: http://www.bluechip-llc.com
			#>
	} # end New-IDPortalObject
		
	# Export the cmdlet
	Export-ModuleMember -Function New-IDPortalObject;		

	#endregion
		
	#region Remove Cmdlets
		
	function Remove-IDPortalObject
    {
		[CmdletBinding( SupportsShouldProcess = $true, ConfirmImpact = 'High' )]
		Param(	
			[Parameter( Mandatory = $true, HelpMessage="Please specify the object id of the object to be removed." )]
			[String] $ObjectID = $(throw "Missing required parameter -ObjectID")
		)
		Begin
        { }
		End
        {
			# Declare local objects and variables
			[String] $filter = "/*[ObjectID='{0}']" -f $ObjectID;
			[Object] $fimObject = $null;
			[Object] $output = New-Object Management.Automation.PSObject;
			[String] $result = $null;
			[String] $warningMessage = $null;

			# Retrieve the target object
			$fimObject = Get-IDPortalObject -Filter $filter -HasValue;
			$warningMessage = "{0} ({1})" -f $fimObject.DisplayName, $fimObject.ObjectID;
				
			# Determine if the object was found
			if ( $fimObject -ne $null )
            {
				# Create the required import objects
				[Object] $importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
									
				# Prepare the import object
				$importObject.ObjectType = $fimObject.ObjectType;
				$importObject.TargetObjectIdentifier = $fimObject.ObjectID;
				$importObject.SourceObjectIdentifier = $fimObject.ObjectID;
				$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Delete;
									
				# Perform the update
				if ( $PSCmdlet.ShouldProcess( $warningMessage ) )
                {
					try
                    {
						if ( $IDPortalCredential -eq $null )
                        {
							$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
						}
                        else
                        {
							$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
						}
						
						$result = 'Success';
					}
                    catch [Exception]
                    {
						$result = $_.Exception.Message;
					} # end update
				} # end confirmation
			} # end DisplayName check
				
			# Add as a property on the output object
			$output | Add-Member -MemberType NoteProperty -Name Result -Value $result;
				
			# Write the output object
			Write-Output $output;
		} # end End
			
		<#
			.SYNOPSIS
				Provides a way to remove a FIM/MIM object.
			.DESCRIPTION
				This cmdlet is intended to provide a consistent method to remove an object from the FIM/MIM Portal.
			.PARAMETER ObjectID
				This is a mandatory parameter which contains the object ID of the FIM/MIM object to be removed.	
			.PARAMETER Confirm
				This is an optional parameter which allows you to override the default confirmation prompt.	
			.INPUTS
				This cmdlet utilizes two new variables which are created and initialized during module import.
					$IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
				You will need to update these prior to calling this cmdlet to ensure appropriate results.
			.OUTPUTS
				This cmdlet returns an object indicating the success of the delete operation.
			.NOTES
				To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
				To see more information, type: "Get-Help [cmdlet name] -detail"
				To see technical information, type: Get-Help [cmdlet name] -full"
			.EXAMPLE
				[Object] $data = Remove-IDPortalObject -ObjectID "32baf7db-36c6-49d3-af6d-0a11e2a393a7";
				
				The preceeding example removes the FIM/MIM Portal object with the specified ID once the confirmation prompt has been
				answered.
			.EXAMPLE
				[Object] $data = Remove-IDPortalObject -ObjectID "32baf7db-36c6-49d3-af6d-0a11e2a393a7" -Confirm:$false;
				
				The preceeding example removes the FIM/MIM Portal object with the specified ID.  This example suppresses the default
				confirmation prompt.
			.LINK
				Company website: http://www.bluechip-llc.com
			#>
	} # end Remove-IDPortalObject
		
	# Export the cmdlet
	Export-ModuleMember -Function Remove-IDPortalObject;
		
	#endregion
		
	#region Set Cmdlets
		
	function Set-IDPortalAttribute
    {
		[CmdletBinding()]
		Param(	
			[Parameter( Mandatory = $true, HelpMessage="Please specify the attribute name." )]
			[String] $AttributeName = $(throw "Missing required parameter -Name"),
				
			[Parameter( Mandatory = $false, HelpMessage="Please specify the attribute value." )]
			[String] $AttributeValue,
				
			[Parameter( Mandatory = $true, HelpMessage="Please specify the object identifier." )]
			[String] $ObjectID = $(throw "Missing required parameter -ObjectID"),
				
			[Parameter( Mandatory = $true, HelpMessage="Please specify the object type." )]
			[String] $ObjectType = $(throw "Missing required parameter -ObjectType"),
				
			[Parameter( Mandatory = $false, HelpMessage="Please specify the object type." )]
			[switch] $Remove = $false
		)
		Begin
        { }
		End
        {
			# Declare local objects and variables
			[String] $dataType = $null;
			[Hashtable] $dataTypes = @{};
			[String] $filter = "/*[ObjectID='{0}']" -f $ObjectID;
			[Object] $fimObject = $null;
			[Boolean] $isMultiValued = $false;
			[Hashtable] $multivalued = @{};
			[Object] $output = New-Object Management.Automation.PSObject;
			[String] $pattern = $null;
			[Boolean] $performUpdate = $false;
			[Hashtable] $regEx = @{};
			[String] $result = $null;
			[String] $schemaFile = "{0}\Schema-{1}.xml" -f $IDPortalDataDirectory, $ObjectType;
			[Boolean] $schemaRetrieved = $false;
			[String] $updateValue = $null;
			[Boolean] $valueExists = $false;

			# Check for a schema definition file
			if ( Test-Path -Path $schemaFile )
            {
				$schemaRetrieved = $true;
			}
            else
            {
				'================================================================================';
				"  Retrieving '$objectType' object schema...";
				"================================================================================`n";
					
				# Retrieve the schema
				if ( Get-IDPortalObject -ObjectType $ObjectType )
                {
					$schemaRetrieved = $true;
				}
			} # end schema test
								
			# Restrieve the object schema attributes
			if ( $schemaRetrieved )
            {
				# Read in the schema data to build properties
				try
                {
					[Management.Automation.PSObject[]] $schemaAttributes = Import-Clixml -Path $schemaFile;
						
					# Build hashtables for data parsing
					$schemaAttributes | ForEach-Object {
						# Get the key value for the attribute/value pairs
						$key = $_.Name;
							
						# Add to the attribute/value pairs only if the key name is defined
						if ( -not ( [String]::IsNullOrEmpty( $key ) ) )
                        {
							# Add to data type pair
							$dataTypes.Add( $key, $_.DataType );
								
							# Add to multi-valued pair
							$multivalued.Add( $key, [Convert]::ToBoolean( $_.Multivalued ) );
								
							# Add to regular expression pair
							if ( -not ( [String]::IsNullOrEmpty( $_.StringRegex ) ) )
                            {
								$regEx.Add( $key, $_.StringRegex );
							}
						} # end empty check
					} # end schema parsing
						
					# Determine if the attribute is available for the specified object
					if ( $dataTypes.Contains( $AttributeName ) )
                    {
						# Determine if the attribute is multi-valued and if so fail
						if ( $multivalued.get_Item( $AttributeName ) )
                        {
							# Update variables
							$fimObject = Get-IDPortalObject -Filter $filter -HasValue;
							$fullyResolved = 0;
							$isMultiValued = $true;
								
							# Determine if the attribute already has values
							if ( $fimObject.$AttributeName -eq $null )
                            {
								$valueExists = $false;
							}
                            else
                            {
								# Determine if the specified value exists
								if ( $fimObject.$AttributeName -contains $Value )
                                {
									$valueExists = $true;
								}
							}
								
							# Retrieve the data type for the specified attribute
							$dataType = $dataTypes.get_Item( $AttributeName );
								
							# Add the data type to the return object
							$output | Add-Member -MemberType NoteProperty -Name DataType -Value $dataType;
								
							# Determine the value and/or if an update can take place based on data type
							switch ( $dataType )
                            {
								'Binary'
                                {
									# Determine if the attribute type is an unsupported binary value
									$result = 'Updates to binary attributes is not supported with this cmdlet';
								}
                                'DateTime'
                                {
									# Build a datetime variable from the provided string
									[DateTime] $dateSource = [DateTime]::Parse( $AttributeValue );
										
									# Convert the date time to something that the FIM/MIM Service understands
									$updateValue = [Xml.XmlConvert]::ToString( $dateSource, [Xml.XmlDateTimeSerializationMode]::Unspecified ) + ".000";
										
									# Change the update status
									$performUpdate = $true;
								}
                                default
                                {
									# Determine if there is a regular expression test on the attribute binding
									if ( $regEx.Contains( $AttributeName ) )
                                    {
										# Retrieve the pattern
										$pattern = $regEx.get_Item( $AttributeName );
											
										# Add the regular expression to the return object
										$output | Add-Member -MemberType NoteProperty -Name StringRegex -Value $pattern;
											
										# Check for null value
										if ( -not ( [String]::IsNullOrEmpty( $AttributeValue ) ) )
                                        {
											# Validate the data
											if ( $AttributeValue -match $pattern )
                                            {
												# Update the import value
												$updateValue = $AttributeValue;
													
												# Change the update status
												$performUpdate = $true;
											}
                                            else
                                            {
												$result = 'Specified value does not match regular expression on attribute binding';
											}
										} # end null check
									}
                                    else
                                    {
										# Read source attribute value into update variable
										if ( [String]::IsNullOrEmpty( $AttributeName ) )
                                        {
											$updateValue = $null;
										}
                                        else
                                        {
											$updateValue = $AttributeValue;
										}
											
										# Change the update status
										$performUpdate = $true;
									} # end regular expression test
								}
							} # end data type case
								
							# Build the FIM/MIM import object and submit to FIM/MIM Service
							if ( $performUpdate )
                            {
								# Create the required import objects
								[Object] $importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange;
								[Object] $importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
									
								# Determine if the value should be removed
								if ( $Remove )
                                {
									# Only try to remove if it exists
									if ( $valueExists )
                                    {
										# Prepare the change operation
										$importChange.Operation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]::Delete;
										$importChange.AttributeName = $AttributeName;
										$importChange.AttributeValue = $updateValue;
										$importChange.FullyResolved = 0;
										$importChange.Locale = "Invariant";
											
										# Prepare the import object
										$importObject.ObjectType = $ObjectType;
										$importObject.TargetObjectIdentifier = $ObjectID;
										$importObject.SourceObjectIdentifier = $ObjectID;
										$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Put;
										$importObject.Changes = (,$importChange);
											
										# Perform the update
										try
                                        {
											if ( $IDPortalCredential -eq $null )
                                            {
												$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
											}
                                            else
                                            {
												$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
											}
											$result = 'Success';
										}
                                        catch [Exception]
                                        {
											$result = $_.Exception.Message;
										} # end update
									}
                                    else
                                    { # Cannot remove a value that is not present
										$result = 'Value is not present to remove';
									} # end Remove value
								}
                                else
                                { # Determine if the value should be added
									# Only try to add if it does not exist
									if ( $valueExists )
                                    {
										$result = 'Value is already present';
									}
                                    else
                                    {
										# Prepare the change operation
										$importChange.Operation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]::Add;
										$importChange.AttributeName = $AttributeName;
										$importChange.AttributeValue = $updateValue;
										$importChange.FullyResolved = 0;
										$importChange.Locale = "Invariant";
											
										# Prepare the import object
										$importObject.ObjectType = $ObjectType;
										$importObject.TargetObjectIdentifier = $ObjectID;
										$importObject.SourceObjectIdentifier = $ObjectID;
										$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Put;
										$importObject.Changes = (,$importChange);
											
										# Perform the update
										try
                                        {
											if ( $IDPortalCredential -eq $null )
                                            {
												$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
											}
                                            else
                                            {
												$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
											}
											$result = 'Success';
										}
                                        catch [Exception]
                                        {
											$result = $_.Exception.Message;
										} # end update
									} # end value test
								} # end value add
							} # end update value check
						}
                        else
                        {
							# Retrieve the data type for the specified attribute
							$dataType = $dataTypes.get_Item( $AttributeName );
								
							# Add the data type to the return object
							$output | Add-Member -MemberType NoteProperty -Name DataType -Value $dataType;
								
							# Determine the value and/or if an update can take place based on data type
							switch ( $dataType )
                            {
								'Binary'
                                {
									# Determine if the attribute type is an unsupported binary value
									$result = 'Updates to binary attributes is not supported with this cmdlet';
								}
                                'DateTime'
                                {
									# Build a datetime variable from the provided string
									[DateTime] $dateSource = [DateTime]::Parse( $AttributeValue );
										
									# Convert the date time to something that the FIM/MIM Service understands
									$updateValue = [Xml.XmlConvert]::ToString( $dateSource, [Xml.XmlDateTimeSerializationMode]::Unspecified ) + ".000";
										
									# Change the update status
									$performUpdate = $true;
								}
                                default
                                {
									# Determine if there is a regular expression test on the attribute binding
									if ( $regEx.Contains( $AttributeName ) )
                                    {
										# Retrieve the pattern
										$pattern = $regEx.get_Item( $AttributeName );
											
										# Add the regular expression to the return object
										$output | Add-Member -MemberType NoteProperty -Name StringRegex -Value $pattern;
											
										# Check for null value
										if ( -not ( [String]::IsNullOrEmpty( $AttributeValue ) ) )
                                        {
											# Validate the data
											if ( $AttributeValue -match $pattern )
                                            {
												# Update the import value
												$updateValue = $AttributeValue;
													
												# Change the update status
												$performUpdate = $true;
											}
                                            else
                                            {
												$result = 'Specified value does not match regular expression on attribute binding';
											}
										} # end null check
									}
                                    else
                                    {
										# Read source attribute value into update variable
										if ( [String]::IsNullOrEmpty( $AttributeName ) )
                                        {
											$updateValue = $null;
										}
                                        else
                                        {
											$updateValue = $AttributeValue;
										}
											
										# Change the update status
										$performUpdate = $true;
									} # end regular expression test
								}
							} # end data type case
								
							# Build the FIM/MIM import object and submit to FIM/MIM Service
							if ( $performUpdate )
                            {
								# Create the required import objects
								[Object] $importChange = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportChange;
								[Object] $importObject = New-Object Microsoft.ResourceManagement.Automation.ObjectModel.ImportObject;
									
								# Prepare the change operation
								$importChange.Operation = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportOperation]::Replace;
								$importChange.AttributeName = $AttributeName;
								$importChange.AttributeValue = $updateValue;
								$importChange.FullyResolved = 1;
								$importChange.Locale = "Invariant";
									
								# Prepare the import object
								$importObject.ObjectType = $ObjectType;
								$importObject.TargetObjectIdentifier = $ObjectID;
								$importObject.SourceObjectIdentifier = $ObjectID;
								$importObject.State = [Microsoft.ResourceManagement.Automation.ObjectModel.ImportState]::Put;
								$importObject.Changes = (,$importChange);
									
								# Perform the update
								try
                                {
									if ( $IDPortalCredential -eq $null )
                                    {
										$importObject | Import-FIMConfig -Uri $IDPortalServiceUri;
									}
                                    else
                                    {
										$importObject | Import-FIMConfig -Uri $IDPortalServiceUri -Credential $IDPortalCredential;
									}
									$result = 'Success';
								}
                                catch [Exception]
                                {
									$result = $_.Exception.Message;
								} # end update
							} # end update value check
						} # end multi-value check
					}
                    else
                    {
						$result = 'The specified attribute is not bound to the specified object';
					} # end attribute exists test
				}
                catch [Xml.XmlException]
                {
					$result = 'Invalid schema file for current object';
				}
			}
				
			# Add as a property on the output object
			$output | Add-Member -MemberType NoteProperty -Name Result -Value $result;
				
			# Write the output object
			Write-Output $output;
		} # end End
			
		<#
			.SYNOPSIS
				Provides a way to update a single attribute on a FIM/MIM object.
			.DESCRIPTION
				This cmdlet is intended to provide a consistent method to update a single attribute 
				values in the FIM/MIM Portal.
			.PARAMETER AttributeName
				This is a mandatory parameter which contains the name of the attribute to update.		
			.PARAMETER AttributeValue
				This is a mandatory parameter which contains the value to update with.		
			.PARAMETER ObjectID
				This is a mandatory parameter which contains the ID of object to update.		
			.PARAMETER ObjectType
				This is a mandatory parameter which contains the type of object to retrieve the schema for.
			.PARAMETER Remove
				This is an optional parameter which is used to remove a single value from a multi-valued attribute.
			.INPUTS
				This cmdlet utilizes two new variables which are created and initialized during module import.
					$IDPortalServiceUri = "http://localhost:5725/ResourceManagementService";
				
				You will need to update these prior to calling this cmdlet to ensure appropriate results.
			.OUTPUTS
				This cmdlet returns an object indicating the success of the update operation.
			.NOTES
				To see the examples, for cmdlets type: "Get-Help [cmdlet name] -examples"
				To see more information, type: "Get-Help [cmdlet name] -detail"
				To see technical information, type: Get-Help [cmdlet name] -full"
			.EXAMPLE
				Set-IDPortalAttribute -AttributeName AccountName -AttributeValue foo -ObjectID <GUID> -ObjectType "Person";
				
				The preceeding example performs an update of the AccountName attribute for the specified object.
			.EXAMPLE
				Set-IDPortalAttribute -AttributeName ProxyAddressCollection -AttributeValue SMTP:foo@some.com -ObjectID <GUID> -ObjectType "Person";
				
				The preceeding example adds the value to a multi-valued attribute.
			.EXAMPLE
				Set-IDPortalAttribute -AttributeName ProxyAddressCollection -AttributeValue SMTP:foo@some.com -ObjectID <GUID> -ObjectType "Person" -Remove;
				
				The preceeding example removes the value to a multi-valued attribute.
			.LINK
				Company website: http://www.bluechip-llc.com
		#>
	} # end Set-IDPortalAttribute
		
	# Export the cmdlet
	Export-ModuleMember -Function Set-IDPortalAttribute;
		
    #endregion
}
else
{
    $displayWarning = @{
		BackgroundColor = "Black";
		ForegroundColor = "Yellow";
	}
	
    Write-Host "`n`n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" @displayWarning;
	Write-Host '!                                                                              !' @displayWarning;
	Write-Host '!                         MODULE FUNCTIONALITY WARNING                         !' @displayWarning;
	Write-Host '!                                                                              !' @displayWarning;
	Write-Host '! This system does not appear to have the FIMAutomation snap-in registered.    !' @displayWarning;
	Write-Host '! Please install this snap-in or move the module to a system that already has  !' @displayWarning;
	Write-Host '! the FIMAutomation snap-in loaded. The default usage is to install the module !' @displayWarning;
	Write-Host '! on the FIM/MIM portal server under the current user profile.                 !' @displayWarning;
	Write-Host '!                                                                              !' @displayWarning;
	Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!`n`n" @displayWarning;
}
