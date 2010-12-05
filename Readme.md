Gitr - Git Responder
=====================

What is it?
--------------
A basis on which to build dev tools that respond to
github commits. Built as an external component
that runs on the same server as the ejabberd server.

What does it require?
----------------------
Exmpp-0.9.5, for one thing.

An externalcomponent compliant XMPP server for 
another. Testing has been on ejabberd.

How do I start it?
-------------------

erl -pa ebin -secret yourpassword -subdomain yoursubdomain -port 8888 -s gitr start

What is on the roadmap?
-----------------------
 * Use file:consult to parse a property list that maps repos to directories, execute git pull in that directory on change

