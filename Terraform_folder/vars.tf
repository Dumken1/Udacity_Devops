variable "prefix" {
  description = "The prefix which should be used for all resources in this work"
}

variable "tag" {
  description = "The tag to be used on the resources deployed on this work"
  type        = map(string)
  default = {
    Name = "UdacityLab1"
  }
}

variable "rgname" {
  description = "This is the resource group which has already been created"
  default = "Azuredevops"
}

variable "location" {
  description = "The variable holds the location name for the resource group"
  default = "East US"
}

variable "username" {
  description = "Use this username to log into the Virtual machine"
  default = "Dumken"
}

variable "accounttype" {
  description = "This variable holds the storage account type"
  default = "Standard_LRS"
}

variable "password" {
  description = "Use this username to log into the Virtual machine"
  default = "!P@ssword123"
}

variable "Image" {
  description = "The name of the Vm image to be used"
  default = "DumkenImage"
}

variable "VmSize" {
  description = "This value is number of VMs to be created."
  validation {
      condition     = var.VmSize <= 3
      error_message = "You are allowed to create atmost 3 Virtual machines"
   }
}