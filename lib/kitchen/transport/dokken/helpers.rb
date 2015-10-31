module Dokken
  module Transport
    module Helpers
      def insecure_ssh_private_key
        <<-EOF
-----BEGIN DSA PRIVATE KEY-----
MIIBuwIBAAKBgQDZsPJal55xqENC7rFTa/+9epkIRIMW/EWEG4Phz9MP/111WZIt
okgu/y4UBHWIFGWgWCSqQTUNxUiL8nzOUZLInBBddI7/0EPoLECh3/48lky0oomk
iYsIQ65DVveFf09qXM15Sto+VIshigOlA5knokulXvevZ6iyS2++8VjpVwIVAKxq
r0+9oVr5JdR9ZhX0msOyQ+3LAoGAZk7ickwKncvsT4iOwBSPgQrlqY63MwbP2sN0
eQKzWkX9/zwVLpqQFAnjyelD3MOb1O+AJaAmL3FJ8FPCG2fzo+gOTRk6Oh7yGoz9
mPBNe3I7DE180z27k9UqpK5VXLELSaR1P/lgRqFCXloOuvwo1KfzcdmCvukCc6AC
wS8iVvgCgYEAyi7XX3Ev12AXgpwRPPbfVltJ9H5Hpll34gc2ORhmCSL6RE42BpAX
uzI7lbGun2dXFsCdDm0DQz3h4JHtTHePd6xXqyPpUda4ktLVtEWMm0XIQNE8P5zP
0gcfqVe4prOYeBLwrvAkyeNY5wosgzGHrQ+/hFwW3s8liEjZaFDhCWYCFASgG6eP
vVnsIrCx2rI5/KEQZ+oG
-----END DSA PRIVATE KEY-----
EOF
      end
    end
  end
end
