module Dokken
  module Driver
    module Helpers
      def insecure_ssh_public_key
        <<-EOF
ssh-dss AAAAB3NzaC1kc3MAAACBANmw8lqXnnGoQ0LusVNr/716mQhEgxb8RYQbg+HP0w//XXVZki2iSC7/LhQEdYgUZaBYJKpBNQ3FSIvyfM5RksicEF10jv/QQ+gsQKHf/jyWTLSiiaSJiwhDrkNW94V/T2pczXlK2j5UiyGKA6UDmSeiS6Ve969nqLJLb77xWOlXAAAAFQCsaq9PvaFa+SXUfWYV9JrDskPtywAAAIBmTuJyTAqdy+xPiI7AFI+BCuWpjrczBs/aw3R5ArNaRf3/PBUumpAUCePJ6UPcw5vU74AloCYvcUnwU8IbZ/Oj6A5NGTo6HvIajP2Y8E17cjsMTXzTPbuT1SqkrlVcsQtJpHU/+WBGoUJeWg66/CjUp/Nx2YK+6QJzoALBLyJW+AAAAIEAyi7XX3Ev12AXgpwRPPbfVltJ9H5Hpll34gc2ORhmCSL6RE42BpAXuzI7lbGun2dXFsCdDm0DQz3h4JHtTHePd6xXqyPpUda4ktLVtEWMm0XIQNE8P5zP0gcfqVe4prOYeBLwrvAkyeNY5wosgzGHrQ+/hFwW3s8liEjZaFDhCWY= test-kitchen
EOF
      end

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

      def data_dockerfile
        <<-EOF
FROM centos:7
MAINTAINER Sean OMeara \"sean@chef.io\"

ENV LANG en_US.UTF-8

RUN yum -y install tar rsync openssh-server passwd git
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ''
RUN ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N ''

RUN mkdir -p /root/.ssh/
COPY authorized_keys /root/.ssh/authorized_keys

EXPOSE 22
CMD [ "/usr/sbin/sshd", "-D", "-p", "22", "-o", "UseDNS=no", "-o", "UsePrivilegeSeparation=no" ]

VOLUME /opt/kitchen
VOLUME /opt/verifier
EOF
      end

      def create_data_image
        return if ::Docker::Image.exist?(data_image)

        tmpdir = Dir.tmpdir
        FileUtils.mkdir_p "#{tmpdir}/dokken"
        File.write("#{tmpdir}/dokken/Dockerfile", data_dockerfile)
        File.write("#{tmpdir}/dokken/authorized_keys", insecure_ssh_public_key)

        i = ::Docker::Image.build_from_dir("#{tmpdir}/dokken", 'nocache' => true, 'rm' => true)
        i.tag('repo' => repo(data_image), 'tag' => tag(data_image), 'force' => true)
      end
    end
  end
end
