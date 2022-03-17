using System;

namespace Replicate
{
	public class Runner 
	{

		// The main entry point for the process
		// When running as Windows service was an option, any argument passed would cause it to run as process.
		// Ignore and always run as process in one thread.
		static void Main(string[] args)
		{
			Console.Out.WriteLine("Running harvester as single threaded process");
			try
			{
				Replicate.harvestDatabaseRegistryList();
			}
			catch (Exception e)
			{
				Console.Error.WriteLine(e.Message + ":" + e.StackTrace);
			}
			Console.Out.WriteLine("Ending harvester process");
		}
	}
}
