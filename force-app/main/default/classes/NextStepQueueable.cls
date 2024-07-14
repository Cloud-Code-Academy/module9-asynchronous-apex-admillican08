/*
 * NextStepQueueable Class Description:
 *
 * Implement the Queueable interface to process records asynchronously.
 * This example processes up to 10 accounts at a time.
 * It removes the Next Step from the accounts and related opportunities.
 *
 * Benefits of using Queueable methods:
 *
 * 1. Chaining Jobs: Allows for the chaining of jobs, meaning you can add another job to the queue from a running job.
 * 2. Stateful Execution: Supports stateful execution, which allows member variables to retain their values between job invocations.
 * 3. High Concurrency: Processes large sets of data without hitting governor limits.
 * 4. Flexibility: Useful for operations that need more flexibility in execution, especially when there's a possibility of chaining or performing related async operations.
 * 5. Enhanced Integration Capabilities: Useful for making asynchronous callouts to external systems, allowing for more extended processing times.
 *
 * For more detailed information, refer to the official Salesforce documentation: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm
 *
 * Note: The class below contains placeholders for implementing a queueable job to update accounts and opportunities.
 */
public with sharing class NextStepQueueable implements Queueable {
  public static final String CLASSNAME = 'NextStepQueueable';
  // Member variable to store the accounts
  private Map<Id, Account> accounts;

  // Constructor to accept the accounts
  public NextStepQueueable(Map<Id, Account> accounts) {
    // Store the accounts in a member variable
    this.accounts = accounts;
  }

  // Method to queue the job; ADM note: shouldn't this have @override?
  public static void enqueueJob() {
    // Get 10 accounts with Next Step populated
    Map<Id, Account> acctMap = new Map<Id, Account>(
      [SELECT Id FROM Account WHERE Next_Step__c != NULL WITH USER_MODE]
    );
    // If there are any accounts, queue the job using System.enqueueJob
    System.enQueueJob(new NextStepQueueable(acctMap));
  }

  /*
   * Update/Uncomment the template code to create a method
   * Method to execute the queueable job
   */
  //[public | private ] [static] data_type execute (input parameters) {
  public void execute(QueueableContext qc) {
    List<Opportunity> oppsToUpd = new List<Opportunity>();
    // Get the accounts from the member variable
    // Get the opportunities related to the accounts
    List<Account> acctLst = [
      SELECT
        Id,
        Next_Step__c,
        (SELECT Id, NextStep FROM Opportunities WHERE NextStep != NULL)
      FROM Account
      WHERE Id IN :accounts.keySet()
      WITH USER_MODE
    ];
    // Remove the Next Step using the helper method
    for (Account acct : acctLst) {
      removeNextStep(acct);
      oppsToUpd.add(acct.Opportunities);
    }
    // Update the accounts
    try {
      update as user acctLst;
    } catch (DMLException de) {
      System.debug(
        'Problem with batch update of account list in ' +
          CLASSNAME +
          ' starting with ' +
          acctLst[0].Id +
          '; ' +
          de.getMessage()
      );
    }
    // Remove the Next Step using the helper method
    for (Opportunity opp : oppsToUpd) {
      removeNextStep(opp);
    }
    // Update the opportunities
    try {
      update as user oppsToUpd;
    } catch (DMLException dme) {
      System.debug(
        'Problem with batch update of opportunity list in ' +
          CLASSNAME +
          ' starting with ' +
          oppsToUpd[0].Id +
          '; ' +
          dme.getMessage()
      );
    }
    // Call the enqueueJob method to queue another job to process more records.
  }

  // Helper method to remove the Next Step
  // Overloaded method to accept an opportunity
  private static void removeNextStep(Opportunity opp) {
    opp.NextStep = null;
  }

  // Helper method to remove the Next Step
  // Overloaded method to accept an account
  private static void removeNextStep(Account acc) {
    acc.Next_Step__c = null;
  }
}
