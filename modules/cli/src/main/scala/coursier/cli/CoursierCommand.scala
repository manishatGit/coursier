package coursier.cli

import caseapp.CommandParser
import caseapp.core.help.CommandsHelp
import coursier.cli.bootstrap.Bootstrap
import coursier.cli.complete.Complete
import coursier.cli.fetch.Fetch
import coursier.cli.install.{Install, InstallPath, Update}
import coursier.cli.launch.Launch
import coursier.cli.publish.Publish
import coursier.cli.publish.sonatype.Sonatype
import coursier.cli.resolve.Resolve
import coursier.cli.spark.SparkSubmit

object CoursierCommand {

  val parser =
    CommandParser.nil
      .add(Bootstrap)
      .add(Complete)
      .add(Fetch)
      .add(Install)
      .add(InstallPath)
      .add(Launch)
      .add(Publish)
      .add(Resolve)
      .add(Sonatype, "sonatype")
      .add(SparkSubmit)
      .add(Update)
      .reverse

  val help =
    CommandsHelp.nil
      .add(Bootstrap)
      .add(Complete)
      .add(Fetch)
      .add(Install)
      .add(InstallPath)
      .add(Launch)
      .add(Publish)
      .add(Resolve)
      .add(Sonatype, "sonatype")
      .add(SparkSubmit)
      .add(Update)
      .reverse

}
