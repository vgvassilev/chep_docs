#!/bin/bash

# Get all event urls
REGISTRATIONS_FORM=$1

# Get all sublinks to the registration
INDIVIDUAL_REGISTRATION_URLS=$(cat $REGISTRATIONS_FORM | grep -o '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//' -e 's/["'"'"']$//' | xargs -I$ echo "https://indico.cern.ch$")

# Display sanity check the number should be the same as the registered participants.
echo "$INDIVIDUAL_REGISTRATION_URLS" | wc -l

# Go get cookie as described here http://linux.web.cern.ch/linux/docs/cernssocookie.shtml,
# namely cern-get-sso-cookie --krb -r -u https://somesite.web.cern.ch/protected -o ~/private/ssocookie.txt
# Then move it locally.

# Go fetch the urls
#mkdir user_registrations
#while read -r line; do
#    REGISTRATION_ID=$(basename $line)
#    echo "Dumpring information about $REGISTRATION_ID from $line to user_registrations/$REGISTRATION_ID.html";
#    curl -L --cookie cookie.txt --cookie-jar cookie.txt $line -o user_registrations/$REGISTRATION_ID.html
#done <<< "$INDIVIDUAL_REGISTRATION_URLS"
# Sanitize content
for file in user_registrations/*.html; do
    [ -e "$file" ] || continue

    # Replace some html special chars.
    REGISTRATION_FORM=$(cat $file | sed -n "/<div id=\"registration-details\">/,/<div class=\"permalink-text\">/p")
    #echo "$REGISTRATION_FORM"
    if [[ $REGISTRATION_FORM = *"not paid yet"* ]]; then
       continue
    fi


    PAYMENT_FORM=$(echo "$REGISTRATION_FORM" | sed -n "/<dl.*>/,/<\/dl>/p")

    PAYMENT_AMOUNT=$(echo "$PAYMENT_FORM" | grep -C1 "Amount" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_DATE=$(echo "$PAYMENT_FORM" | grep -C1 "Payment date" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_PAIDWITH=$(echo "$PAYMENT_FORM" | grep -C1 "Paid with" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_PAIDAMOUNT=$(echo "$PAYMENT_FORM" | grep -C1 "Paid amount" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_EXTRAFEE=$(echo "$PAYMENT_FORM" | grep -C1 "Extra fee" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_PAYMENTMETHOD=$(echo "$PAYMENT_FORM" | grep -C1 "Payment Method" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')
    PAYMENT_TRANSACTIONID=$(echo "$PAYMENT_FORM" | grep -C1 "Transaction ID" | tail -n1 | sed -n 's:.*<dd>\(.*\)</dd>.*:\1:p')

    #echo "$PAYMENT_FORM"

    PERSON_FIRSTNAME=$(cat $file | sed -n "/<div id=\"registration-details\">/,/<div class=\"permalink-text\">/p" | grep -C2 "First Name" | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    PERSON_LASTNAME=$(cat $file | sed -n "/<div id=\"registration-details\">/,/<div class=\"permalink-text\">/p" | grep -C2 "Last Name" | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    PERSON_EMAIL=$(cat $file | sed -n "/<div id=\"registration-details\">/,/<div class=\"permalink-text\">/p" | grep -C2 "Email" | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    PERSON_AFFILIATION=$(cat $file | sed 's/\&amp;/\\\&/g' | sed -n "/<div id=\"registration-details\">/,/<div class=\"permalink-text\">/p" | grep -C2 "Affiliation" | tail -n1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    echo "$PERSON_FIRSTNAME"
    echo "$PERSON_LASTNAME"
    echo "$PERSON_EMAIL"
    echo "$PERSON_AFFILIATION"

    echo "$PAYMENT_AMOUNT"
    echo "$PAYMENT_DATE"
    echo "$PAYMENT_PAIDWITH"
    echo "$PAYMENT_PAIDAMOUNT"
    echo "$PAYMENT_EXTRAFEE"
    echo "$PAYMENT_PAYMENTMETHOD"
    echo "$PAYMENT_TRANSACTIONID"

    # Generate the template
    mkdir tmp
    cp payment_receipt/CHEP-logo.png tmp/
    cp payment_receipt/receipt_template.tex tmp/
    # define the template details.
    echo -n "
    %% Conference Details Variables 
    \renewcommand{\EventFullName}{23rd International Conference on Computing in High-Energy and Nuclear Physics}
    \renewcommand{\EventStartEnd}{9-13 July 2018}
    \renewcommand{\EventLocation}{Sofia, Bulgaria}
    \renewcommand{\EventURL}{http://chep2018.org/}
    \renewcommand{\EventLogo}{CHEP-logo.png}

    \renewcommand{\AuthorName}{$PERSON_FIRSTNAME $PERSON_LASTNAME}
    \renewcommand{\InstituteName}{$PERSON_AFFILIATION}
    " > tmp/params.tex
    
    echo -n "
    %% Payment Details Variables
    Conference fee & 500 EUR                \\\\
    Payment date   & $PAYMENT_DATE          \\\\
    " > tmp/table.tex
    [ -n "$PAYMENT_PAIDWITH" ]   &&    echo -n "Paid with      & $PAYMENT_PAIDWITH      \\\\" >> tmp/table.tex
    [ -n "$PAYMENT_PAIDAMOUNT" ] &&    echo -n "Paid amount    & $PAYMENT_PAIDAMOUNT    \\\\" >> tmp/table.tex;
    [ -n "$PAYMENT_EXTRAFEE" ] &&      echo -n "Extra fees     & $PAYMENT_EXTRAFEE      \\\\" >> tmp/table.tex;
    [ -n "$PAYMENT_PAYMENTMETHOD" ] && echo -n "Payment method & $PAYMENT_PAYMENTMETHOD \\\\" >> tmp/table.tex;
    [ -n "$PAYMENT_TRANSACTIONID" ] && echo -n "Transaction ID & $PAYMENT_TRANSACTIONID" >> tmp/table.tex;


    cd tmp
    pdflatex receipt_template.tex > /dev/null
    cd ..
    RECEIPT_FILENAME="to_send/receipt_${PERSON_FIRSTNAME}_${PERSON_LASTNAME}.pdf"
    mv tmp/receipt_template.pdf "$RECEIPT_FILENAME"

    rm -fr tmp
    # Mails to be sent. Format: First Name; email; filename.pdf
    echo "$PERSON_FIRSTNAME;$PERSON_EMAIL;$RECEIPT_FILENAME" >> receipt_map.txt
done

echo "In order to clean up run: rm  to_send/*; rm -fr tmp; rm receipt_map.txt;"

