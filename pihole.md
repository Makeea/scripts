#

## What is Pi-hole

1.  **Ad Blocking**: Pi-hole is primarily known as a network-wide ad blocker. It intercepts DNS queries and blocks those matching its list of known ad-serving domains. This means that it can block ads on all devices on your network without needing ad-blocking extensions on each device.
2.  **Improved Performance**: Pi-hole can speed up your internet browsing by blocking unwanted ads and trackers. Ads can be resource-intensive, slowing page load times and consuming valuable bandwidth.
3.  **Privacy Protection**: Pi-hole doesn't just block ads. It can also block trackers that monitor your internet activity. This can significantly enhance your privacy when browsing the Internet.
4.  **Network-Level Control**: Unlike browser-based ad blockers, Pi-hole works at the network level. This means it can block ads in places other than your web browser, such as in-app ads on your phone or smart TV.
5.  **Insight into Your Network**: Pi-hole provides detailed statistics about the DNS queries made on your network, giving you insight into what devices and applications are doing.
6.  **Open Source and Community Supported**: Pi-hole is an open-source project. This means its source code is freely available for inspection and modification. It also has a large community of users who contribute to its development and provide support.

## Why You Should Set Up Pi-hole Now

1.  **Protect Your Online Privacy**: With the increasing number of online trackers and data harvesting techniques, it's essential to take control of your online privacy now more than ever. Pi-hole can help you with this by blocking unwanted trackers.
2.  **Improve Your Internet Browsing Experience**: By blocking ads and trackers, Pi-hole can help pages load faster, reduce bandwidth usage, and provide a cleaner, more enjoyable browsing experience.
3.  **It's Easy to Set Up**: Despite its powerful features, Pi-hole is easy to set up on a Raspberry Pi or other Linux-based systems. Even if you're not a tech expert, many easy-to-follow guides are available (like this one!) to help you through the process.
4.  **Enhanced Control Over Your Network**: Pi-hole controls what your network's devices can and can't do. This is especially important in households with children or businesses where network security and efficiency are crucial.
5.  **Future-Proof Your Network**: As the Internet evolves, so do ads and trackers. Using a tool like Pi-hole that receives regular updates from an active community ensures you stay one step ahead.

In conclusion, Pi-hole is a versatile, powerful, and user-friendly tool that offers significant benefits regarding privacy, performance, and control over your internet browsing experience. Whether you're a privacy-conscious individual, a parent, or a business owner, there's much to gain from setting up Pi-hole on your network.

## Step 1: Install Pi-hole To install Pi-hole, follow these steps:

1. Update your system first:

```bash

sudo apt update

sudo apt upgrade -y

```

2. Install Pi-hole:

```bash

curl -sSL https://install.pi-hole.net | bash

```

This command will run the Pi-hole installation script.

3. Follow the on-screen instructions to complete the setup. Note your admin web interface password at the end of the installation process. You'll need this later.

# Setup Unbound

What is Unbound? it is a type of DNS server known as a "recursive DNS server" or "resolver." When you use the Internet, your device must frequently translate domain names (like [www.example.com][1]) into IP addresses. This is done using DNS (Domain Name System).

By default, your device will use the DNS servers configured by your ISP or those set manually in your network settings. These could be Google's DNS servers, OpenDNS, Cloudflare, or others. When you make a DNS request, these servers will provide the IP address associated with your requested domain.

However, there are a few potential issues with this. One is privacy: these servers can see all of your DNS queries, which gives them a lot of information about your internet usage. Some DNS providers may log this data and use it for commercial purposes.

Another issue is that the DNS server could be compromised or used to serve incorrect results, either due to a mistake or malicious intent.

This is where Unbound comes in. When you use Unbound, your device will make DNS queries to Unbound, which will then perform the DNS resolution itself, communicating directly with the root DNS servers and the servers for the appropriate top-level domain. This is why it's called a "recursive" resolver: it does the whole resolution process rather than relying on another server.

This has a few benefits:

1.  **Privacy**: Because Unbound makes the DNS resolution itself, third-party DNS servers do not see your DNS queries. This can significantly improve your privacy.
2.  **Security**: Unbound supports DNSSEC, which allows it to verify that the DNS responses it receives are authentic. This can protect against specific attacks where a malicious party tries to manipulate DNS responses.
3.  **Performance**: In some cases, using Unbound can improve DNS resolution times because Unbound will cache responses and can serve them directly if the same request is made again.
4.  **Control**: With Unbound, you have complete control over your DNS resolution. You can configure it in any way you like and be sure it's doing exactly what you want.

Using Unbound with Pi-hole can give you greater control over your DNS, improve your privacy and security, and improve performance. Using Unbound with Pi-hole is optional, but it can be a beneficial addition.

Here are the steps to set up Unbound:

1. Install Unbound:

```bash

sudo apt install unbound -y

```

2. Then, configure Unbound:

```bash

sudo nano /etc/unbound/unbound.conf.d/pi-hole.conf

```

Add the following to the file:

```bash

server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 0

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    #root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # IP fragmentation is unreliable on the Internet today, and can cause
    # transmission failures when large DNS messages are sent via UDP. Even
    # when fragmentation does work, it may not be secure; it is theoretically
    # possible to spoof parts of a fragmented DNS message, without easy
    # detection at the receiving end. Recently, there was an excellent study
    # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
    # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
    # in collaboration with NLnet Labs explored DNS using real world data from the
    # the RIPE Atlas probes and the researchers suggested different values for
    # IPv4 and IPv6 and in different scenarios. They advise that servers should
    # be configured to limit DNS messages sent over UDP to a size that will not
    # trigger fragmentation on typical network links. DNS servers can switch
    # from UDP to TCP when a DNS response is too big to fit in this limited
    # buffer size. This value has also been suggested in DNS Flag Day 2020.
    edns-buffer-size: 1232

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Ensure privacy of local IP ranges
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10

```

Save and close the file (Ctrl + X, Y, Enter).

3\. Restart Unbound to apply the changes:

```bash

sudo service unbound restart

```

4\. Now, you need to set Pi-hole to use Unbound as its DNS resolver. Access the Pi-hole admin interface by going to `http://<your-pi-hole-ip-address>/admin,` going to "Settings" -> "DNS" and setting "Upstream DNS Servers" to `127.0.0.1#5353`.

**Optional**: Download the current root hints file (the list of primary root servers which are serving the domain "." - the root domain). Update it roughly every six months. Note that this file changes infrequently. This is only necessary if you are not installing unbound from a package manager. If you do this optional step, you will need to uncomment the root-hints: configuration line in the suggested config file.

```bash

wget https://www.internic.net/domain/named.root -qO- | sudo tee /var/lib/unbound/root.hints

```

### Step 3: Create a Shortcut to Disable Pi-hole

You can create a shortcut to disable the Pi-hole for a certain amount of time. You'll need the WEB PASSWORD from your Pi-hole setup.

1.  Fetch the password:

```bash
cat /etc/pihole/setupVars.conf | grep WEB PASSWORD
```

This will output something like WEBPASSWORD=abcdef123456.

2.  Use this password to create a link that you can use to disable Pi-hole:

```bash
http://<your-pi-hole-ip-address>/admin/api.php?disable=300&auth=<your-webpassword>
```

3.  Replace <your-pi-hole-ip-address> with your Pi-hole's IP address and <your-webpassword> with the password you obtained in the previous step. This link will disable Pi-hole for 300 seconds (5 minutes). You can change the number after disable= to the number of seconds you want to disable Pi-hole.

That's it! You have now set up Pi-hole with Unbound and created a shortcut to disable Pi-hole quickly.

## Firebog

Provides a curated collection of blocklists for use with Pi-hole. Blocklists are lists of domains known to serve ads, trackers, and other undesirable content. Adding these blocklists to Pi-hole enhances its ability to prevent your devices from connecting to these unwanted domains.

```bash
https://firebog.net
```

The Firebog categorizes these lists into three types:

1.  **Suspicious Lists**: These lists contain domains reported or observed engaging in suspicious activities like phishing or distributing malware.
2.  **Advertising Lists**: These lists contain domains that are known to serve ads.
3.  **Tracking & Telemetry Lists**: These lists contain domains that are known to track users' activities or collect telemetry data.

Why you might want to use The Firebog's blocklists with Pi-hole:

1.  **Comprehensive**: The Firebog's blocklists are extensive and updated regularly, providing a wide range of domains to block.
2.  **Categorized**: The categorization of lists into Suspicious, Advertising, and Tracking & Telemetry helps you choose the lists that align with your privacy and ad-blocking needs.
3.  **Community-Driven**: These lists are maintained by a community of users and are open-source, making them transparent and reliable.

Here's how you can add blocklists from The Firebog to your Pi-hole setup:

1.  Visit The Firebog website.
2.  You'll see several categories of lists. Each list has a direct URL. You will use this URL to add it to your Pi-hole.
3.  In the Pi-hole admin interface, navigate to Group Management > Adlists.
4.  In the Address field, paste the URL of the list you want to add.
5.  Click "Add," and the list will be added to Pi-hole's blocklists.
6.  Repeat this process for each list you want to add.

Remember to regularly update your blocklists in Pi-hole to ensure they are up-to-date with the latest domains to block

## Links

https://docs.pi-hole.net/main/basic-install/

https://docs.pi-hole.net/guides/dns/unbound/

https://firebog.net/
