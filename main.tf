variable "region" {}
variable "account" {}

output "primary" {
    value = "${lookup(var.primary_azs, format("\"%s-%s\"", var.account, var.region))}"
}
output "secondary" {
    value = "${lookup(var.secondary_azs, format("\"%s-%s\"", var.account, var.region))}"
}
output "tertiary" {
    value = "${lookup(var.tertiary_azs, format("\"%s-%s\"", var.account, var.region))}"
}
output "list_all" {
    value = "${lookup(var.list_all, format("\"%s-%s\"", var.account, var.region))}"
}
output "az_count" {
    value = "${lookup(var.az_counts, format("\"%s-%s\"", var.account, var.region))}"
}
output "list_letters" {
    value = "${lookup(var.list_letters, format("\"%s-%s\"", var.account, var.region))}"
}
