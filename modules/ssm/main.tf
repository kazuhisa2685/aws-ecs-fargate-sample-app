resource "aws_ssm_parameter" "example" {
  name  = "/myapp/db/password"
  type  = "SecureString"
  value = "mypassword123"
}
